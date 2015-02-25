require 'rubygems'
require 'sinatra'
require 'json'
 
class GitHubUpdater
 
def self.update?(json)
(JSON.parse(json)["ref"] == "refs/heads/master")
end
 
def self.git_pull
`cd /project/directory && git checkout master && git pull origin master`
end
 
end
 
set :port, 54321
 
post '/' do
GitHubUpdater.git_pull if GitHubUpdater.update?(params[:payload])
end 