#!/usr/bin/env bash

#set time-zone Pacific time
#sudo timedatectl set-timezone America/Los_Angeles

#update and install realmd
sudo apt-get update
sudo apt-get install -y krb5-user samba sssd sssd-tools libnss-sss libpam-sss ntp ntpdate realmd adcli

#read host input
read -p "What is host's name: " hname
read -p "What is host's IP: " mip
read -p "What is domain's name: " dname

#set hosts file /etc/hosts
gip=`ip a | grep $mip | awk '{print $2}' | awk -F/ '{print $1}'`
echo "$gip $hname.$dname $hname" >> /etc/hosts
#sed -i '/127.0.0.1/a$gip $hname.$dname $hname' /etc/hosts

#add domain to ntp.conf
echo -e "\nserver $dname" >> /etc/ntp.conf

systemctl stop ntp
ntpdate $dname
systemctl start ntp

#read domain input
read -p "Please provide domain name again, must be in CAP e.g. COMPANY.NET : " dname
read -p "What is domain Administrator's name: " adname

#join to domain
realm join --verbose $dname -U "$adname@$dname" --install=/

#set rnds
sed -i '/default_realm/a rnds=false' /etc/krb5.conf

#use just username without long FQDN
sed -i 's/use_fully_qualified_names = True/#use_fully_qualified_names = True/' /etc/sssd/sssd.conf
sed -i 's/fallback_homedir = \/home\/%u@%d/fallback_homedir = \/home\/%u/' /etc/sssd/sssd.conf

#allow domain users login xrdp
sed -i 's/access_provider = ad/access_provider = simple/' /etc/sssd/sssd.conf

systemctl restart sssd

#allow ssh login using password
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

systemctl restart ssh

#append new line, create user's folder
sed -i '/pam_sss.so/a session optional pam_sss.so' /etc/pam.d/common-session
