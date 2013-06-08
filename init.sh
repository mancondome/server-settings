#!/bin/bash

echo "`whoami` ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/`whoami` > /dev/null
sudo chmod 440 /etc/sudoers.d/`whoami` 2> /dev/null

sudo apt-get install git