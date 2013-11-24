#!/bin/bash
# chef-server
DEB_PACKAGE='chef-server_11.0.8-1.ubuntu.12.04_amd64.deb'
wget -q -nc -P /tmp/ https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/$DEB_PACKAGE
sudo dpkg -i /tmp/$DEB_PACKAGE
sudo chef-server-ctl reconfigure
# chef-client
curl -L https://www.opscode.com/chef/install.sh | sudo bash