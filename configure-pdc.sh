#!/bin/bash
add-apt-repository ppa:niklas-andersson/dcpromo
apt-get update
debconf-set-selections /vagrant/dcpromo.debconf
apt-get install dcpromo ldap-utils
dcpromo

sed -i "/\[global\]/a\\\tldap server require strong auth = no" /etc/samba/smb.conf
samba-tool domain passwordsettings set --complexity=off --history-length=0 --min-pwd-age=0 --max-pwd-age=0

shutdown -r now