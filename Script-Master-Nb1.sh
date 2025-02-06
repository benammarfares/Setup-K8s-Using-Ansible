#!/bin/bash

sudo usermod -aG sudo $USER
sudo apt install openssh-server
sudo systemctl stop ufw
sudo systemctl disable ufw
