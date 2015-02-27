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

class PuppetmasterSync < Sinatra::Base

  def initialize
    @logger = ::Logger.new($stderr)
    @branch_mappings = {}
    super
  end

  def parse_config_file
    unless ENV.has_key? "PUPPETMASTER_SYNC_CONFIG_FILE"
      @logger.error("ENV missing 'PUPPETMASTER_SYNC_CONFIG_FILE' key")
      halt 401
    end

    config_file = ENV["PUPPETMASTER_SYNC_CONFIG_FILE"]

    unless File.readable? config_file
      @logger.error("Configuration file #{config_file} is not readable")
      halt 401
    end

    YAML.load(config_file)
  end

  # Become puppet, cd to puppet checkout directory, check out the branch, update it
  def update_puppetmaster_directory(branch, directory, user)
    system %{su - #{user} bash -c "cd #{directory} && git checkout #{directory} && git pull origin #{directory}"}
  end

  # https://developer.github.com/webhooks/#payloads
  #
  # Github sends our configured secret as an HMAC hex digest of the payload, using the # hook’s secret 
  # as the key (if configured).

  configure do
    set :app_file, __FILE__
    set :dump_errors, true
  end

  before do

    unless ENV.has_key? "PUPPETMASTER_SYNC_SECRET"
      @logger.error("ENV missing 'PUPPETMASTER_SYNC_SECRET' key")
      halt 401
    end

    GITHUB_WEBHOOK_SECRET = ENV["PUPPETMASTER_SYNC_SECRET"]

    CONFIG = parse_config_file

    if !headers.has_key? "X-Hub-Signature"
      @logger.error("Received request with no authorization (X-Hub-Signature header missing) - skipping")
      halt 401
    end

    @logger.info("Processing Github delivery ID #{headers['X-Github-Delivery']}")

    # From https://developer.github.com/webhooks/securing/
    request.body.rewind
    signature = "sha1=" + \
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha1"), GITHUB_WEBHOOK_SECRET, request.body.read)
    unless Rack::Utils.secure_compare(signature, headers["X-Hub-Signature"])
      halt 401, "Github push request - signature / secret mismatch: skipping"
    end

    request.body.rewind
  end

  # Happens when a push is done to the puppet-config repo
  post '/' do

    if !params.has_key? :payload
      @logger.error("Received request with no payload - skipping")
      halt 400
    end

    gh_webhook_response = JSON.parse(params[:payload])

    unless gh_webhook_response.has_key? "pusher"
      @logger.error("Received Github service hook response that is not of type 'push': skipping")
      halt 400
    end

    branch = gh_webhook_response["ref"].split("/")[-1]

    unless CONFIG["branches"].has_key? branch
      @logger.error("Received Github push service hook request for branch we don't monitor #{branch}: skipping")
      halt 404, "Not watching for #{branch} updates"
    end

    update_puppetmaster_directory(branch, CONFIG["branches"][branch], CONFIG["user"])
    name, email = gh_webhook_response["pusher"]["name"], gh_webhook_response["pusher"]["email"]
    @logger.info("updated #{branch} on behalf of #{name} (#{email})")

    true
  end

  get '/' do
    @logger.error("oops")
  end

  run! if $0 == __FILE__

end
