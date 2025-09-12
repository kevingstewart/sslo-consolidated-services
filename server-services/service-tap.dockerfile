FROM ubuntu:20.04
LABEL reference="https://www.digitalocean.com/community/tutorials/how-to-install-suricata-on-ubuntu-20-04"

# Update and install required packages
RUN apt update && \
    apt upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common bridge-utils apt-utils net-tools iproute2 tcpdump iputils-ping dnsutils vim nano curl jq

# Install suricata
RUN apt update && \
    add-apt-repository ppa:oisf/suricata-stable -y && \
    apt install -y suricata

# Replace all instances of eth0 and eth2 in suricata.yaml with eth1
RUN sed -i 's/community-id: false/community-id: true/g' /etc/suricata/suricata.yaml && \
    sed -i 's/eth0/eth1/g' /etc/suricata/suricata.yaml && \
    sed -i 's/eth2/eth1/g' /etc/suricata/suricata.yaml

# Add info to the bottom of suricata.yaml
RUN <<"EOF" cat >> /etc/suricata/suricata.yaml
detect-engine:
  - rule-reload: true
EOF

# Create the entrypoint script
RUN <<EOF cat > /entrypoint.sh
#!/bin/bash
/usr/bin/suricata -c /etc/suricata/suricata.yaml -s signature.rules -i \${INTERFACE:-eth0}
EOF

RUN chmod +x /entrypoint.sh

# Enable additional suricata modules and then update
RUN /usr/bin/suricata-update enable-source tgreen/hunting
RUN /usr/bin/suricata-update enable-source abuse.ch/urlhaus
RUN /usr/bin/suricata-update enable-source et/open
RUN /usr/bin/suricata-update enable-source oisf/trafficid
RUN /usr/bin/suricata-update

ENTRYPOINT ["/entrypoint.sh"]
