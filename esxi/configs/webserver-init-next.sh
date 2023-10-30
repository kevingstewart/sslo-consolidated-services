#!/bin/bash 

apt update -y
apt install apt-utils net-tools iproute2 -y

sed -ie 's/^#\(Include .*httpd-ssl.conf\)/\1/' /usr/local/apache2/conf/httpd.conf
sed -ie 's/^#\(LoadModule .*mod_ssl.so\)/\1/' /usr/local/apache2/conf/httpd.conf
sed -ie 's/^#\(LoadModule .*mod_socache_shmcb.so\)/\1/' /usr/local/apache2/conf/httpd.conf

ifconfig eth0:0 172.19.0.11/24
ifconfig eth0:1 172.19.0.12/24
ifconfig eth0:2 172.19.0.13/24

/usr/local/bin/httpd-foreground
