FROM ubuntu:20.04
LABEL reference="https://www.digitalocean.com/community/tutorials/how-to-install-suricata-on-ubuntu-20-04"

RUN apt update && \
    apt upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common bridge-utils apt-utils net-tools iproute2 tcpdump iputils-ping dnsutils vim nano curl jq
    
RUN apt update && \
    add-apt-repository ppa:oisf/suricata-stable -y && \
    apt install -y suricata

RUN sed -i 's/community-id: false/community-id: true/g' /etc/suricata/suricata.yaml && \
    sed -i 's/eth0/eth1/g' /etc/suricata/suricata.yaml && \
    sed -i 's/eth2/eth1/g' /etc/suricata/suricata.yaml

RUN <<"EOF" cat >> /etc/suricata/suricata.yaml
detect-engine:
  - rule-reload: true
EOF

RUN <<EOF cat > /entrypoint.sh
#!/bin/bash
/usr/bin/suricata -c /etc/suricata/suricata.yaml -s signature.rules -i \${INTERFACE:-eth0}
EOF

RUN chmod +x /entrypoint.sh
RUN /usr/bin/suricata-update enable-source tgreen/hunting
RUN /usr/bin/suricata-update enable-source abuse.ch/urlhaus
RUN /usr/bin/suricata-update enable-source et/open
RUN /usr/bin/suricata-update enable-source oisf/trafficid
RUN /usr/bin/suricata-update

ENTRYPOINT ["/entrypoint.sh"]
