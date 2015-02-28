###########################################
# Rack-compliant applicationt that will:
###########################################
#
# * Listen for incoming Github push requests from our Puppet repo
# * Validate the request is ours by checking the X-Hub-Signature header and decoding it
#   using the locally provided secret (PUPPETMASTER_SYNC_SECRET environment variable)
# * Update the branch on the puppetmaster provided in the webhook if it is present
#   in the YAML file branch mappings you provide (PUPPETMASTER_SYNC_CONFIG_FILE variable)

require 'rubygems'
require 'logger'
require 'sinatra'
require 'json'
require 'pry'

class PuppetmasterSync < Sinatra::Base
  def initialize
    @branch_mappings = {}
    @@config = nil
    super
  end

  def PuppetmasterSync.config=(new_config)
    @@config = new_config
  end

  def PuppetmasterSync.config
    @@config
  end

  def read_config_file
    unless ENV.has_key? "PUPPETMASTER_SYNC_CONFIG_FILE"
      logger.error("ENV missing 'PUPPETMASTER_SYNC_CONFIG_FILE' key")
      halt 401
    end

    config_file = ENV["PUPPETMASTER_SYNC_CONFIG_FILE"]

    unless File.readable? config_file
      logger.error("Configuration file #{config_file} is not readable")
      halt 401
    end

    YAML.load(IO.read(config_file))
  end

  def update_puppetmaster_checkout_for(branch, directory)
    system %{cd '#{directory}' && git checkout '#{branch}' && git pull origin '#{branch}'}
  end

  configure do
    set :app_file, __FILE__
    set :dump_errors, true
    enable :logging
  end

  # https://developer.github.com/webhooks/#payloads
  #
  # Github sends our configured secret as an HMAC hex digest of the payload, using the hook’s secret
  # as the key.
  #
  # Test payload available in spec/support/sample_push.json

  before do
    unless ENV.has_key? "PUPPETMASTER_SYNC_SECRET"
      logger.error("ENV missing 'PUPPETMASTER_SYNC_SECRET' key")
      halt 401
    end

    PuppetmasterSync.config = read_config_file

    if !request.env.has_key? "HTTP_X_HUB_SIGNATURE"
      logger.error("Received request with no authorization (X-Hub-Signature header missing) - skipping")
      halt 401
    end

    logger.info(
      "github[#{request.env['HTTP_X_GITHUB_DELIVERY']}]: processing #{request.env['HTTP_X_GITHUB_EVENT']} " +
      request.env["HTTP_X_HUB_SIGNATURE"]
    )

    # From https://developer.github.com/webhooks/securing/
    request.body.rewind
    signature = "sha1=" + \
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha1"), ENV["PUPPETMASTER_SYNC_SECRET"], request.body.read)
    unless Rack::Utils.secure_compare(signature, request.env["HTTP_X_HUB_SIGNATURE"])
      halt 401, "Github push request - signature / secret mismatch: skipping"
    end

    request.body.rewind
  end

  # Happens when a push is done to the puppet configuration repository
  post '/' do

    webhook_response_json = request.body.read

    if webhook_response_json.length.eql?(0)
      logger.error("Received request with no payload - skipping")
      halt 400
    end

    gh_webhook_response = JSON.parse(webhook_response_json)

    unless gh_webhook_response.has_key? "pusher"
      logger.error("Received Github service hook response that is not of type 'push': skipping")
      halt 400
    end

    branch_name = gh_webhook_response["ref"].split("/")[-1]

    unless PuppetmasterSync.config["branches"].has_key? branch_name
      logger.error("Received Github push service hook request for branch we don't monitor (#{branch_name}): skipping")
      halt 200, "Not watching for #{branch_name} updates"
    end

    branch_dir = PuppetmasterSync.config["branches"][branch_name]

    update_puppetmaster_checkout_for(branch_name, branch_dir)

    name, email = gh_webhook_response["pusher"]["name"], gh_webhook_response["pusher"]["email"]
    logger.info("updated #{branch_name} on behalf of #{name} (#{email})")

    true
  end

  get '/ping' do
    "pong"
  end

  run! if $0 == __FILE__
end
