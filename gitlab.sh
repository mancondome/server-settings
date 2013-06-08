#!/bin/bash

sudo apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl git-core redis-server postfix checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev

sudo apt-get install -y ruby1.9.3
sudo gem install bundler


# Create a git user for Gitlab
sudo adduser --disabled-login --gecos 'GitLab' git
# Go to home directory
cd /home/git
# Clone gitlab shell
sudo -u git git clone https://github.com/gitlabhq/gitlab-shell.git
cd gitlab-shell
# switch to right version for v5.0
sudo -u git git checkout v1.1.0
sudo -u git git checkout -b v1.1.0
sudo -u git cp config.yml.example config.yml
# Edit config and replace gitlab_url
# with something like 'http://domain.com/'
sudo -u git emacs config.yml
# Do setup
sudo -u git ./bin/install


# Install the database packages
sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev
# MySQL secure installation
mysql_secure_installation
# Password for gitlab
echo -n "password for MySQL user \"root\"> "
read MYSQL_ROOT_PASSWORD
echo -n "password for MySQL user \"gitlab\"> "
read MYSQL_GITLAB_PASSWORD
# Create a user and database for GitLab.
mysql -uroot --password=$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS \`gitlabhq_production\` DEFAULT CHARACTER SET \`utf8\` COLLATE \`utf8_unicode_ci\`;GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON \`gitlabhq_production\`.* TO 'gitlab'@'localhost' IDENTIFIED BY '$MYSQL_GITLAB_PASSWORD';"

cd /home/git
# Clone GitLab repository
sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab
# Go to gitlab dir
cd /home/git/gitlab
# Checkout to stable release
sudo -u git -H git checkout 5-0-stable
cd /home/git/gitlab

# Copy the example GitLab config
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml

# Make sure to change "localhost" to the fully-qualified domain name of your
# host serving GitLab where necessary
# sudo -u git -H vim config/gitlab.yml

# Make sure GitLab can write to the log/ and tmp/ directories
sudo chown -R git log/
sudo chown -R git tmp/
sudo chmod -R u+rwX  log/
sudo chmod -R u+rwX  tmp/

# Create directory for satellites
sudo -u git -H mkdir /home/git/gitlab-satellites

# Create directory for pids and make sure GitLab can write to it
sudo -u git -H mkdir tmp/pids/
sudo chmod -R u+rwX  tmp/pids/

# Copy the example Unicorn config
sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb

# Configure GitLab DB settings
cat <<EOF | sudo -u git tee config/database.yml
#
# PRODUCTION
#
production:
  adapter: mysql2
  encoding: utf8
  reconnect: false
  database: gitlabhq_production
  pool: 5
  username: gitlab
  password: "$MYSQL_GITLAB_PASSWORD"
EOF
sudo chmod 600 config/database.yml

# Install Gems
cd /home/git/gitlab
sudo gem install charlock_holmes --version '0.6.9'
sudo -u git -H bundle install --deployment --without development test postgres

# Initialise Database and Activate Advanced Features
sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production
# Install Init Script
sudo curl --output /etc/init.d/gitlab https://raw.github.com/gitlabhq/gitlab-recipes/5-0-stable/init.d/gitlab
sudo chmod +x /etc/init.d/gitlab
sudo update-rc.d gitlab defaults 21
# Check Application Status
sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production
sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production
# Start Your GitLab Instance
sudo service gitlab start


# Nginx settings
sudo apt-get install -y nginx
cat <<EOF | sudo tee /etc/nginx/sites-available/gitlab
# GITLAB
# Maintainer: @randx
# App Version: 5.0

upstream gitlab {
  server unix:/home/git/gitlab/tmp/sockets/gitlab.socket;
}

server {
  listen `wget -q -O - ipcheck.ieserver.net`:80 default_server;
  server_name `hostname -f`;
  root /home/git/gitlab/public;

  # individual nginx logs for this gitlab vhost
  access_log  /var/log/nginx/gitlab_access.log;
  access_log  /var/log/nginx/gitlab_access.log;
  access_log  /var/log/nginx/gitlab_access.log;
  error_log   /var/log/nginx/gitlab_error.log;

  location / {
    # serve static files from defined root folder;.
    # @gitlab is a named location for the upstream fallback, see below
    try_files $uri $uri/index.html $uri.html @gitlab;
  }

  # if a file, which is not found in the root folder is requested,
  # then the proxy pass the request to the upsteam (gitlab unicorn)
  location @gitlab {
    proxy_read_timeout 300; # https://github.com/gitlabhq/gitlabhq/issues/694
    proxy_connect_timeout 300; # https://github.com/gitlabhq/gitlabhq/issues/694
    proxy_redirect     off;

    proxy_set_header   X-Forwarded-Proto $scheme;
    proxy_set_header   Host              $http_host;
    proxy_set_header   X-Real-IP         $remote_addr;

    proxy_pass http://gitlab;
  }
}
EOF

# sudo curl --output /etc/nginx/sites-available/gitlab https://raw.github.com/gitlabhq/gitlab-recipes/5-0-stable/nginx/gitlab
sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
sudo service nginx restart