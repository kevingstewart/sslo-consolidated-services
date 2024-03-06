#!/bin/bash 

apt update -y && apt upgrade -y
apt install apt-utils net-tools iproute2 tcpdump vim nano iputils-ping iptables -y

sysctl net.ipv4.ip_forward=1
sed -i -e 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 80 -j REDIRECT --to-port 3128

ip route delete default
ip route add default via 198.19.98.245
ip route add 10.1.10.0/24 via 198.19.98.7
ipaddr=$(ip addr show dev eth0 |egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.' | cut -d' ' -f2)
ip route add 8.8.8.8 via ${ipaddr}1

echo "nameserver 8.8.8.8" > /etc/resolv.conf

/sbin/entrypoint.sh
