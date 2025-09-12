FROM ubuntu:18.04
LABEL maintainer="DeepDiver1975"
LABEL reference="https://github.com/DeepDiver1975"

ARG ARG_LOCAL_SYSLOG

# Update and install required packages
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y c-icap libicapapi-dev clamav curl less vim nano libc-icap-mod-virus-scan syslog-ng net-tools tcpdump iputils-ping && \
    usermod -a -G c-icap c-icap && \
    mkdir -p /var/run/c-icap && \
    touch /var/run/c-icap/c-icap.id && \
    chown -R c-icap:c-icap /var/run/c-icap && \
    /usr/bin/freshclam && \
    chown -R c-icap:c-icap /etc/c-icap/ && \
    echo "Include clamav_mod.conf" >> /etc/c-icap/virus_scan.conf

# Create the entrypoint script
RUN <<"EOF" cat > /entrypoint.sh
#!/bin/bash

# Update syslog-ng.conf with local syslog info from environment variable
sed -i -e "s/^@define local_syslog.*/@define local_syslog \"$ARG_LOCAL_SYSLOG\"/" /etc/syslog-ng/syslog-ng.conf
service syslog-ng restart

# Start the c-icap service
/usr/bin/c-icap -f /etc/c-icap/c-icap.conf -D -N
EOF

RUN chmod +x /entrypoint.sh

# Create the c-icap configuration file
RUN <<EOF cat > /etc/c-icap/c-icap.conf
## Paths
PidFile           /var/run/c-icap/c-icap.pid
CommandsSocket    /var/run/c-icap/c-icap.ctl
ModulesDir        /usr/lib/x86_64-linux-gnu/c_icap
ServicesDir       /usr/lib/x86_64-linux-gnu/c_icap
TemplateDir       /usr/share/c_icap/templates/
LoadMagicFile     /etc/c-icap/c-icap.magic
TmpDir            /tmp

## User/System
User c-icap
Group nogroup
ServerAdmin you@your.address
ServerName YourServerName

## ACL/Port
acl all src 0.0.0.0/0.0.0.0
icap_access allow all
Port 1344

## Handlers
Timeout                       300
MaxKeepAliveRequests          100
KeepAliveTimeout              600
StartServers                  1
MaxServers                    10
MinSpareThreads               10
MaxSpareThreads               20
ThreadsPerChild               10
MaxRequestsPerChild           0
MaxMemObject                  131072
Pipelining                    on

## Modules
Module common clamav_mod.so
clamav_mod.MaxScanSize 100M
Module logger sys_logger.so

## Debug/Logging
DebugLevel 1
ServerLog /var/log/c-icap/server.log
AccessLog /var/log/c-icap/access.log

Logger sys_logger
sys_logger.access all
sys_logger.Facility local7
sys_logger.access_priority info
sys_logger.server_priority info

## Services
Service antivirus_module virus_scan.so
ServiceAlias srv_clamav virus_scan
ServiceAlias avscan virus_scan?allow204=on&sizelimit=off&mode=simple

## Services: virus_scan
virus_scan.ScanFileTypes TEXT DATA EXECUTABLE ARCHIVE GIF JPEG MSOFFICE
virus_scan.SendPercentData            5
virus_scan.StartSendPercentDataAfter  2M
virus_scan.MaxObjectSize              5M
EOF

# Add information to the bottom on the syslog-ng.conf file to support c-icap logs
RUN <<"EOF" cat >> /etc/syslog-ng/syslog-ng.conf
@define local_syslog "foo"
destination d_relay {network("`local_syslog`" port(514) transport("udp") flags(syslog-protocol));};
filter f_relay {facility(local7) and match("VIRUS" value("MESSAGE"));};
log {source(s_src);filter(f_relay);destination(d_relay);};
EOF

RUN chmod a+w /etc/syslog-ng/

USER c-icap

ENTRYPOINT ["/entrypoint.sh"]
