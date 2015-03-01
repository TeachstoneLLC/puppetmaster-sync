# Overview

Syncs Puppet branches on a puppet master when a push is received for a branch the program is configured to update

```
            _______________     push webhook   _____________________      if the branch exists
  O   git   |             |     __________     |                    |     ____________________
 _|_  ----> | puppet repo | --> | POST / | --> | puppetmaster_sync  | --> | cd dir; git pull |
  |   push  | on Github   |     ----------     |                    |     --------------------
 / \        ---------------     on Github      ----------------------
```
Server code based on http://gilesbowkett.blogspot.com/2012/06/heroku-style-deployment-on-ec2.html

# Functionality

* Listens for incoming Github push web hooks POST requests - https://developer.github.com/webhooks/
* If the Github secret received matches the configured secret (see https://developer.github.com/v3/repos/hooks/#create-a-hook) then we accept the webhook request - otherwise we drop it
* If the branch for the push hook matches a branch configured in the configuration file:
  * cd to the directory specified for that configuration
  * Run ```git pull``` to update the branch locally

# Pre-requisites

* Working puppetmaster set up using multiple environments (https://docs.puppetlabs.com/puppet/latest/reference/environments_configuring.html)
* Git / puppet repo set up with web hook configured to send pushes to this process
* User this app runs as has filesystem permissions enabled to allow it to run ```git pull```
* User this app runs as is set up on puppet master with an SSH deploy key for Github that allows it to do git pulls without human intervention or passphrase
* Modern version of ruby (version 2.0 or higher)
* Webhook set up with secret configured on Github (put same on the client)
  * Disable SSL verification as we use self-signed certs

# Configuration

## Puppetmaster set up

* Configure the Rack application using your ruby application server of choice (passenger, puma, thin, etc). We use Nginx with puma and set up puma to listen on a Unix domain socket, then configure Nginx to proxy requests to the application using that domain socket (http://stackoverflow.com/questions/17450672/how-to-start-puma-with-unix-socket)
* Open access to your puppetmaster from the Github API server address blocks (important to not allow the *world* to access this endpoint) - https://help.github.com/articles/what-ip-addresses-does-github-use-that-i-should-whitelist/
* Create the YAML configuration file and put it somewhere on the server
  (see spec/support/sample_config.yml for an example configuration file)
* Ensure the environment variable PUPPETMASTER\_SYNC\_SECRET is set to the Github secret set for the Github webservice hook in the environment the puppetmaster_sync application runs in.
* Ensure the environment variable PUPPETMASTER\_SYNC\_CONFIG\_FILE is set to the fully qualified path of your YAML configuration file for the puppetmaster_sync application.
* Start the application - you will see a stdout.log and stderr.log under the log directory of the application (when using puma) if the application started successfully.

## Github setup

* Add a webhook for push events for the Github repo you wish to update from (https://developer.github.com/webhooks/#events)
* Configure webhook to use a secret (https://developer.github.com/webhooks/securing/)
* Disable SSL validation if your receiving side uses a self-signed SSL certificate or you do not use SSL (you should use SSL though!)
* Add the URL you configured on the Puppetmaster to the webhook
* Test the endpoint by pushing to a branch you've configured your application for. If the whole process works, you will see log messages from puppetmaster_sync stating that a branch was updated on behalf of the user who triggered the push (in stderr.log if using puma). Example:

```
[2015-02-27T22:13:31.157490 #19023]  INFO -- : updated master on behalf of a_user (a_user@example.com)
```

## Configuration file

* branches - a hash, with the branch name as key and the directory as value. Example:

```
branches:
  develop: /etc/puppet/develop
  master:  /etc/puppet/master
```

# Running in development mode

```
bundle install --path vendor/bundle --binstubs
bin/puma -w 1  # or any other rack compliant server (but puma is included in Gemfile)
```
