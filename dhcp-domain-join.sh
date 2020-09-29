#!/usr/bin/env bash

#set time-zone Pacific time
#timedatectl set-timezone America/Los_Angeles

#update and install realmd
apt-get update
apt-get install -y krb5-user samba sssd sssd-tools libnss-sss libpam-sss ntp ntpdate realmd adcli

#read host input
read -p "What is host's name: " hname
read -p "What is host's IP: " mip
read -p "What is domain's name: " dname

#set hosts file /etc/hosts
gip=`ip a | grep $mip | awk '{print $2}' | awk -F/ '{print $1}'`
#echo "$gip $hname.$dname $hname" | tee -a /etc/hosts
grep -qxF "$gip $hname.$dname $hname" /etc/hosts
if [ $? -ne 0 ]; then
  echo "$gip $hname.$dname $hname" | tee -a /etc/hosts
else
    echo "Hostname already set"    
fi

#add domain to ntp.conf
#echo "server $dname" | tee -a /etc/ntp.conf
grep -qxF "server $dname" /etc/ntp.conf
if [ $? -ne 0 ]; then
  echo "server $dname" | tee -a /etc/ntp.conf
else
    echo "NTP server already set"    
fi

systemctl stop ntp
ntpdate $dname
#systemctl start ntp

#read domain input
read -p "Please provide domain name again, must be in CAP e.g. COMPANY.NET : " dname
read -p "What is domain Administrator's name: " adname

#join to domain
realm join --verbose $dname -U "$adname@$dname" --install=/

#set domain administrator sudoer
grep -qxF "%$adname" /etc/sudoers
if [ $? -ne 0 ]; then
  echo "$adname ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers
else
    echo "User $adname sudoers already set"    
fi

#set rnds
grep -qxF "rnds=false" /etc/krb5.conf
if [ $? -ne 0 ]; then
  sed -i '/default_realm/a rnds=false' /etc/krb5.conf
else
    echo "rnds=false already set"    
fi

#use just username without long FQDN
#sed -i 's/use_fully_qualified_names = True/#use_fully_qualified_names = True/' /etc/sssd/sssd.conf
#sed -i 's/fallback_homedir = \/home\/%u@%d/fallback_homedir = \/home\/%u/' /etc/sssd/sssd.conf
grep -qxF "#use_fully_qualified_names = True" /etc/sssd/sssd.conf
if [ $? -ne 0 ]; then
  sed -i 's/use_fully_qualified_names = True/#use_fully_qualified_names = True/' /etc/sssd/sssd.conf
else
    echo "use_fully_qualified_names already set"    
fi

grep -qxF "fallback_homedir = \home\%u@%d" /etc/sssd/sssd.conf
if [ $? -ne 0 ]; then
  sed -i 's/fallback_homedir = \/home\/%u@%d/fallback_homedir = \/home\/%u/' /etc/sssd/sssd.conf
else
    echo "fallback_homedir already set"    
fi

#allow domain users login xrdp
#sed -i 's/access_provider = ad/access_provider = simple/' /etc/sssd/sssd.conf
grep -qxF "access_provider = simple" /etc/sssd/sssd.conf
if [ $? -ne 0 ]; then
  sed -i 's/access_provider = ad/access_provider = simple/' /etc/sssd/sssd.conf
else
    echo "access_provider already set"    
fi

#systemctl restart sssd

#allow ssh login using password
#sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
grep -qxF "PasswordAuthentication no" /etc/sssd/sssd.conf
if [ $? -ne 0 ]; then
  sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
else
    echo "access_provider already set"    
fi

#systemctl restart ssh

#append new line, create user's folder
#sed -i '/pam_sss.so/a session required pam_mkhomedir.so skel=/etc/skel/ umask=0077' /etc/pam.d/common-session
grep -qxF "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" /etc/sssd/sssd.conf
if [ $? -ne 0 ]; then
  #echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" | tee -a /etc/pam.d/common-session
   sed -i '/pam_sss.so/a session required pam_mkhomedir.so skel=/etc/skel/ umask=0077' /etc/pam.d/common-session
else
    echo "pam_mkhomedir already set"    
fi

systemctl start ntp
systemctl restart sssd
systemctl restart ssh

#need manual check for multiple entries
#/etc/pam.d/common-session
#/ect/sudoers
