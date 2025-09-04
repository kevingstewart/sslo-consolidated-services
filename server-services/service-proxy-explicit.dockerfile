FROM ubuntu:bionic-20190612
LABEL maintainer="sameer@damagehead.com"
LABEL reference="https://github.com/sameersbn/docker-squid"

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y squid=3.5.27* apt-utils net-tools iproute2 tcpdump vim nano iputils-ping dnsutils \
 && rm -rf /var/lib/apt/lists/*

RUN <<EOF cat > "/sbin/entrypoint.sh"
#!/bin/bash
set -e

ip route delete default
ip route add default via \$ARG_SVC_GATEWAY
ip route add \$ARG_CLIENT_SUBNET via \$ARG_SVC_INGRESS
ipaddr=\$(ip addr show dev eth0 |egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.' | cut -d' ' -f2) && ip route add 8.8.8.8 via \${ipaddr}1
echo "nameserver 8.8.8.8" > /etc/resolv.conf

create_log_dir() {
  mkdir -p /var/log/squid
  chmod -R 755 /var/log/squid
  chown -R proxy:proxy /var/log/squid
}

create_cache_dir() {
  mkdir -p /var/spool/squid
  chown -R proxy:proxy /var/spool/squid
}

create_log_dir
create_cache_dir

# allow arguments to be passed to squid
if [[ \${1:0:1} = '-' ]]; then
  EXTRA_ARGS="\$@"
  set --
elif [[ \${1} == squid || \${1} == \$(which squid) ]]; then
  EXTRA_ARGS="\${@:2}"
  set --
fi

# default behaviour is to launch squid
if [[ -z \${1} ]]; then
  if [[ ! -d /var/spool/squid/00 ]]; then
    echo "Initializing cache..."
    \$(which squid) -N -f /etc/squid/squid.conf -z
  fi
  echo "Starting squid..."
  exec \$(which squid) -f /etc/squid/squid.conf -NYCd 1 \${EXTRA_ARGS}
else
  exec "\$@"
fi
EOF

RUN chmod 755 /sbin/entrypoint.sh

RUN <<EOF cat > "/etc/squid/squid.conf"
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 1025-65535
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localhost
http_access allow all
http_port 3128

coredump_dir /var/spool/squid

refresh_pattern -i (/cgi-bin/|\?) 0	0%	0
refresh_pattern (Release|Packages(.gz)*)\$      0       20%     2880
refresh_pattern .		0	20%	4320

cache deny all

logfile_rotate 0
logformat authheader %ts.%03tu %6tr %>a %Ss/%03>Hs %<st %rm %ru "%{X-Authenticated-User}>h" %Sh/%<a %mt
access_log /var/log/squid/access.log authheader
EOF

EXPOSE 3128/tcp

ENTRYPOINT ["/sbin/entrypoint.sh"]
