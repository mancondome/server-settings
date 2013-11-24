#!/bin/bash
# chef-server
sudo dpkg -i https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chef-server_11.0.8-1.ubuntu.12.04_amd64.deb
# chef-client
curl -L https://www.opscode.com/chef/install.sh | sudo bash