#!/bin/bash

sudo apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl git-core redis-server postfix checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev

sudo apt-get install -y ruby1.9.3
sudo gem install bundler


# Create a git user for Gitlab
sudo adduser --disabled-login --gecos 'GitLab' git
# Login as git
sudo su git
# Go to home directory
cd /home/git
# Clone gitlab shell
git clone https://github.com/gitlabhq/gitlab-shell.git
cd gitlab-shell
# switch to right version for v5.0
git checkout v1.1.0
git checkout -b v1.1.0
cp config.yml.example config.yml
# Edit config and replace gitlab_url
# with something like 'http://domain.com/'
emacs config.yml
# Do setup
./bin/install
logout


# Install the database packages
sudo apt-get install -y mysql-server mysql-client libmysqlclient-dev
# MySQL secure installation
mysql_secure_installation
# Password for gitlab
echo -n "password for MySQL user \"gitlab\"> "
read MYSQL_PASSWORD
# Create a user and database for GitLab.
mysql -uroot -p -e <<EOS
	CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
	CREATE DATABASE IF NOT EXISTS `gitlabhq_production` DEFAULT CHARACTER SET `utf8` COLLATE `utf8_unicode_ci`;
	GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON `gitlabhq_production`.* TO 'gitlab'@'localhost';
EOS
# Try connecting to the new database with the new user
sudo -u git -H mysql -u gitlab -p -D gitlabhq_production


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
sudo -u git cp config/database.yml.mysql config/database.yml

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
sudo apt-get install nginx
sudo curl --output /etc/nginx/sites-available/gitlab https://raw.github.com/gitlabhq/gitlab-recipes/5-0-stable/nginx/gitlab
sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
sudo service nginx restart