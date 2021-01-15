#!/bin/bash 

apt update -y
apt install apt-utils net-tools iproute2 vim nano -y

sed -ie 's/^#\(Include .*httpd-ssl.conf\)/\1/' /usr/local/apache2/conf/httpd.conf
sed -ie 's/^#\(LoadModule .*mod_ssl.so\)/\1/' /usr/local/apache2/conf/httpd.conf
sed -ie 's/^#\(LoadModule .*mod_socache_shmcb.so\)/\1/' /usr/local/apache2/conf/httpd.conf

device=$(ip a |egrep -o 'inet 192.168.100\..*' | cut -d' ' -f7)
ifconfig ${device}:0 192.168.100.11/24
ifconfig ${device}:1 192.168.100.12/24
ifconfig ${device}:2 192.168.100.13/24

/usr/local/bin/httpd-foreground
