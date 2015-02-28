# Overview

Syncs Puppet branches on a puppet master when a push is received for a branch the program is configured to update

```
            _______________     push webhook   _____________________   (if branch in config file)
  O   git   |             |     __________     |                    |     ____________________
 _|_  ----> | puppet repo | --> | POST / | --> | puppetmaster_sync  | --> | cd dir; git pull |
  |   push  | on Github   |     ----------     |                    |     --------------------
 / \        ---------------                    ----------------------
```
Server code based on http://gilesbowkett.blogspot.com/2012/06/heroku-style-deployment-on-ec2.html

# Functionality

* Listens for incoming Github push web hooks
* If the secret received matches the configured secret (see https://developer.github.com/v3/repos/hooks/#create-a-hook) then we accept the webhook request - otherwise we drop it
* If the branch for the push hook matches a branch configured in the configuration file:
  * cd to the directory specified for that configuration
  * Run ```git pull`` to update the branch locally

# Pre-requisites

* Working puppetmaster set up using multiple environments (https://docs.puppetlabs.com/puppet/latest/reference/environments_configuring.html)
* Git / puppet repo set up with web hook configured to send pushes to this process
* User this app runs as has filesystem permissions enabled to allow it to run ```git pull```
* User this app runs as is set up on puppet master with an SSH deploy key for Github that allows it to do git pulls without human intervention or passphrase
* Modern version of ruby (version 2.0 or higher)
* Webhook set up with secret configured on Github (put same on the client)
  * Disable SSL verification as we use self-signed certs

# Configuration

These parameters are set as environment variables

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
