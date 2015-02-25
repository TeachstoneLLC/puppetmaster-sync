# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../puppetmaster_sync.rb',  __FILE__)
run PuppetmasterSync
