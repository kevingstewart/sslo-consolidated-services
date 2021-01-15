#!/bin/bash 

apt update -y
apt install apt-utils net-tools iproute2 -y

sed -i 's/HOME_NET: \"\[192.168.0.0\/16,10.0.0.0\/8,172.16.0.0\/12\]\"/#HOME_NET: \"\[192.168.0.0\/16,10.0.0.0\/8,172.16.0.0\/12\]\"/g' /etc/suricata/suricata.yaml
sed -i 's/#HOME_NET: \"any\"/HOME_NET: \"any\"/g' /etc/suricata/suricata.yaml
sed -i 's/EXTERNAL_NET: \"!$HOME_NET\"/#EXTERNAL_NET: \"!$HOME_NET\"/g' /etc/suricata/suricata.yaml
sed -i 's/#EXTERNAL_NET: \"any\"/EXTERNAL_NET: \"any\"/g' /etc/suricata/suricata.yaml
sed -i 's/eth0/eth1/g' /etc/suricata/suricata.yaml
sed -i 's/eth2/eth1/g' /etc/suricata/suricata.yaml
sed -i 's/\/usr\/bin\/suricata \$\{ARGS\} \$\{SURICATA_OPTIONS\} \$@//g' /docker-entrypoint.sh

ip route delete default
ip route add default via 198.19.64.245
ip route add 10.1.10.0/24 via 198.19.64.7

suricata -c /etc/suricata/suricata.yaml -i eth1
