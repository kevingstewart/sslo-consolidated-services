#!/bin/bash 

apt update -y
apt install apt-utils net-tools iproute2 tcpdump tshark vim nano -y

ip route delete default
ip route add default via 198.19.96.245
ip route add 10.1.10.0/24 via 198.19.96.7
ipaddr=$(ip addr show dev eth0 |egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.' | cut -d' ' -f2)
ip route add 8.8.8.8 via ${ipaddr}1

sed -i 's/http_access deny all/http_access allow all/g' /etc/squid/squid.conf

echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "cache deny all" >> /etc/squid/squid.conf
echo 'logformat authheader %ts.%03tu %6tr %>a %Ss/%03>Hs %<st %rm %ru "%{X-Authenticated-User}>h" %Sh/%<a %mt' >> /etc/squid/squid.conf
echo 'access_log /var/log/squid/access.log authheader' >> /etc/squid/squid.conf

/sbin/entrypoint.sh
