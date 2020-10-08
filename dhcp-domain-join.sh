#!/usr/bin/env bash

echo "Update and install packages..."

#update and install realmd
apt-get update
apt-get install -y krb5-user samba sssd sssd-tools libnss-sss libpam-sss ntp ntpdate realmd adcli


#add domain to ntp.conf
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
read -p "Please provide domain name, must be in CAP e.g. COMPANY.NET : " dname
read -p "What is domain Administrator's account allow to join VM to Domain: " adname

#join to domain
realm join --verbose $dname -U "$adname@$dname" --install=/

#set domain administrator sudoer
grep -qxF "%$adname" /etc/sudoers
if [ $? -ne 0 ]; then
  echo "$adname ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers
else
    echo "User $adname sudoers already set"
fi

#set rdns
grep -qxF "rdns=false" /etc/krb5.conf
if [ $? -ne 0 ]; then
  sed -i '/default_realm/a rdns=false' /etc/krb5.conf
else
    echo "rdns=false already set"
fi

#use just username without long FQDN
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
grep -qxF "access_provider = simple" /etc/sssd/sssd.conf
if [ $? -ne 0 ]; then
  sed -i 's/access_provider = ad/access_provider = simple/' /etc/sssd/sssd.conf
else
    echo "access_provider already set"
fi

#allow ssh login using password
grep -qxF "PasswordAuthentication no" /etc/sssd/sssd.conf
if [ $? -ne 0 ]; then
  sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
else
    echo "access_provider already set"
fi

#append new line, create user's folder
grep -qxF "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" /etc/sssd/sssd.conf
if [ $? -ne 0 ]; then
  #echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" | tee -a /etc/pam.d/common-session
   sed -i '/pam_sss.so/a session required pam_mkhomedir.so skel=/etc/skel/ umask=0077' /etc/pam.d/common-session
else
    echo "pam_mkhomedir already set"
fi

echo "Restarting services.."
systemctl start ntp
systemctl restart sssd
systemctl restart ssh

echo ""
echo "Done!"
echo ""
