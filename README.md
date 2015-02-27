# Overview

Syncs Puppet branches on a puppet master when a push is received for a branch the program is configured to update

Server code based on http://gilesbowkett.blogspot.com/2012/06/heroku-style-deployment-on-ec2.html

# Functionality

* Listens for incoming Github push web hooks
* If the secret received matches the configured secret (see https://developer.github.com/v3/repos/hooks/#create-a-hook) then we accept the webhook request - otherwise we drop it
* If the branch for the push hook matches a branch configured in the configuration file:
  * cd to the directory specified for that configuration
  * Run ```git pull`` to update the branch locally

# Pre-requisites

* Working puppetmaster set up using multiple environments (https://docs.puppetlabs.com/puppet/latest/reference/environments\_configuring.html)
* Git / puppet repo set up with web hook configured to send pushes to this process
* Puppet user is used to run puppet
* User set up on puppet master with SSH key for Github (deploy key) that allows it to do git pulls without human intervention
* App set up to run as the user that is allowed to do a git pull on the server from Github
* Modern version of ruby (version 2.0 or higher)
* Webhook set up with secret configured on Github (put same on the client)
  * Disable SSL verification as we use self-signed certs

# Configuration

* Ensure PUPPETMASTER\_SYNC\_SECRET is set to the Github secret set for the Github webservice hook
* Ensure PUPPETMASTER\_SYNC\_CONFIG\_FILE is set to the fully qualified path of your YAML configuration file.

## Configuration file

* branches - a hash, with the branch name as key and the directory as value. Example:

```
branches:
  develop: /etc/puppet/develop
  master:  /etc/puppet/master
```

# Running

```
bundle install --path vendor/bundle --binstubs
bin/puma -w 1  # or any other rack compliant server (but puma is included in Gemfile)
```
