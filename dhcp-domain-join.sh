#!/usr/bin/env bash

#get all input from user
#host input
read -p "What is host's name: " hname
read -p "What is host's IP: " mip

#domain input
read -p "What is domain name, must be in CAP e.g. CWQI.NET: " vdom
read -p "What is domain admin name: " dname

#set time-zone Pacific time
#sudo timedatectl set-timezone America/Los_Angeles

#update and install realmd
sudo apt-get update
sudo apt-get install krb5-user samba sssd sssd-tools libnss-sss libpam-sss ntp ntpdate realmd adcli

#read host input
#moved to begining

#set hosts file /etc/hosts
gip=`ip a | grep $mip | awk '{print $2}' | awk -F/ '{print $1}'`
sudo echo "$gip $hname.domain.com name $hname" >> /etc/hosts

#add domain to ntp.conf
sudo echo -e "\nserver cwqi.net" >> etc/ntp.conf

sudo systemctl stop ntp
sudo ntpdate aaddscontoso.com
sudo systemctl start ntp

#read domain input
#moved to begining

#join to domain
sudo realm join --verbose $vdom -U '$dname@$vdom' --install=/

#set rnds
sudo sed -i '/default_realm/a rnds=false' testfile /etc/krb5.conf

#use just username without long FQDN
sudo sed -i 's/use_fully_qualified_names = True/#use_fully_qualified_names = True/' /etc/sssd/sssd.conf
sudo sed -i 's/fallback_homedir = \/home\/%u@%d/fallback_homedir = \/home\/%u/' /etc/sssd/sssd.conf

#allow domain users login xrdp
sudo sed -i 's/access_provider = ad/access_provider = simple/' /etc/sssd/sssd.conf

sudo systemctl restart sssd

#allow ssh login using password
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

sudo systemctl restart ssh

#append new line, create user's folder
sudo sed -i '/pam_sss.so/a session optional pam_sss.so' testfile /etc/pam.d/common-session
