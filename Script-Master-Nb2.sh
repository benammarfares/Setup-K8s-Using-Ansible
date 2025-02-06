#!/bin/bash

# Add the necessary lines to /etc/ssh/sshd_config
sudo sh -c 'echo "PasswordAuthentication no" >> /etc/ssh/sshd_config'
sudo sh -c 'echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config'
sudo sh -c 'echo "PermitRootLogin no" >> /etc/ssh/sshd_config'

# Restart the SSH service to apply changes
sudo systemctl restart ssh

# Remove lock files
sudo rm /var/lib/dpkg/lock-frontend
sudo rm /var/lib/dpkg/lock
sudo dpkg --configure -a
