# SSL Orchestrator Consolidated Services Architecture
Docker compose configurations to create all of the SSLO security services on a single Ubuntu VM, to both simplify and dramatically reduce resource utilization in a virtual environment.

## About
This Docker Compose configuration supports the **F5 UDF** demo environment, which itself supports 802.1Q VLAN tags. This also reduces the number of physical interfaces and connections required. The Docker Compose "server" file contains:

- An inline layer 3 inspection service with Suricata
- An inline transparent proxy inspection service with Squid
- An inline explicit proxy inspection service with Squid
- An ICAP inspection service with c-icap and Clamav
- A TAP inspection service with Suricata
- A Wireshark TAP inspection service with web interface on port 3000
- An NGINX webserver instance listening on HTTP:80 and HTTPS:443 with a sample travel site, and HTTPS:444 supporting PQC ciphers
- A Juiceshop webserver instance for WAF testing
- A Syslog server with web interface configured to capture ICAP server logs, listening on port 8282

The Docker Compose "client" file contains:

- A Guacamole (jumphost) instance to provide web-based RDP access to the Client VM desktop

## Installation / Instructions

Perform the following steps to create the consolidated server and client services architecture on a set of Ubuntu 20.04+ instances.

Minimum requirements:

* Ubuntu 20.04 and higher
* Docker 20.10 and higher
* Docker Compose 1.29 and higher

----
#### Installing Docker
```bash
sudo apt update
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ${USER}
```
----

### Server Instance

* **Step 1**: Configure the Ubuntu server instance with the following interfaces:

  * Management (ens5)
  * Layer 3 services (ens6)
  * Tap service (ens7)
  * Layer 2 service inbound (ens8)
  * Layer 2 service outbound (ens9)
 
* **Step 2**: Configure bridging for the Layer 2 service

  * Install and configure bridge-utils:
    ```bash
    sudo apt-get update -y
    sudo apt-get install bridge-utils -y
    ```
  * Configure the network bridge and other interfaces via Netplan. The following assumes ens7 and ens8 are the two interfaces to bridge:
    ```bash
    sudo vi /etc/netplan/50-cloud-init.yaml
  
    network:
    version: 2
    ethernets:
        ens5:
            dhcp4: true
            dhcp6: false
        ens6:
            dhcp4: false
            dhcp6: false
        ens7:
            dhcp4: false
            dhcp6: false
        ens8:
            dhcp4: false
            dhcp6: false
        ens9:
            dhcp4: false
            dhcp6: false
  
    bridges:
        br0:
           interfaces:
             - ens7
             - ens8
           dhcp4: false
           dhcp6: false
    ```
  * Update the Netplan configuration and then verify:
    ```bash
    sudo netplan apply
    ifconfig
    ```
  * Disable iptables processing on the bridge interfaces:
    ```bash
    sudo su
    echo "0" > /proc/sys/net/bridge/bridge-nf-call-iptables
    exit
    ```
    
* **Step 3**: Download the configuration package:

  ```bash
  git clone https://github.com/kevingstewart/sslo-consolidated-services.git
  cd sslo-consolidated-services
  ```
  
* **Step 4**: Modify the YAML files (as required)

  The Docker Compose YAML files in the ```server-services``` folder are all tuned to the interfaces described above. Modify these as required. The services with to interfaces have a "to-service" interface and a "from-service" interface. For these "inline" services, inspectable traffic flows into the to-service interface and flows out of the from-service interface. In this pre-defined configuration, the inline service's gateway is the .245 address on the from-service subnet (ex. 198.19.64.245). In most cases, these layer 3 services also need a static return route for the client's network. In this pre-defined configuration, the static return route points to the .7 address on the to-service subnet (ex. 198.19.64.7).
  
  | Service                   | Interface(s)       | Address(es)                         |
  |---------------------------|--------------------|-------------------------------------|
  | Layer 3 Service           | ens6.60<br>ens6.70 | 198.19.64.30/25<br>198.19.64.130/25 |
  | Explicit Proxy Service    | ens6.30<br>ens6.40 | 198.19.96.30/25<br>198.19.96.130/25 |
  | Transparent Proxy Service | ens6.10<br>ens6.20 | 198.19.98.30/25<br>198.19.98.130/25 |
  | ICAP service              | ens6.50            | 198.19.97.50/25                     |
  | Webserver / Juiceshop     | ens6.80            | 192.168.100.0/24                    |
  | TAP Service               | ens7.1000          | ---                                 |
  | Wireshark TAP Service     | ens7.1001          | ---                                 |
  
* **Step 5**: Deploy the containers

  The main Compose file calls individual Compose files that then build the containers locally via Dockerfiles. The build process happens once and then caches the containers for local startup so   that no Internet access is required on restart. The first time through, the build process will take some time.
  ```bash
  docker compose -f compose-server.yaml up -d
  ```
  Once the build processes are complete and the containers are up, verify that everything is a running state:
  ```bash
  docker ps
  ```

* **Step 6**: Access Utility services

  * The webserver instance is listening on 192.168.100.10 with the following port assignments:
    * Port 80: HTTP listener with sample travel site content
    * Port 443: HTTPS listener with sample travel site content
    * Port 444: HTTPS listener with PQC cipher enabled (X25519MLKEM768) and simple HTTP response with negotiated TLS information
  * The Juiceshop instance is listening on 192.168.100.20, port 3000
  * Wireshark TAP service web interface is listening on the management network interface IP, port 3000
  * The syslog service web interface is listening on the management network interface IP, port 8282

----

### Client Instance

* **Step 1**: Download the configuration package:

  ```bash
  git clone https://github.com/kevingstewart/sslo-consolidated-services.git
  cd sslo-consolidated-services
  ```

* **Step 2**: Deploy the containers

  The main Compose file calls individual Compose files that then build the containers locally via Dockerfiles. The build process happens once and then caches the containers for local startup so   that no Internet access is required on restart. The first time through, the build process will take some time.
  ```bash
  docker compose -f compose-client.yaml up -d
  ```
  Once the build processes are complete and the containers are up, verify that everything is a running state:
  ```bash
  docker ps
  ```
  
* **Step 2**: Access Guacamole Utility service

  * The Guacamole service web interface is listening on the management network interface IP, port 8080

----

### Configuration Details

Below find the configuration details for all of the containers maintained in this project.

<details>
<summary><b>Layer 3 Service</b></summary>
  
* Ubuntu 20.04 base image with Suricata installation and routing configuration
* Routing configuration:
  ```bash
  ip route delete default
  ip route add default via $ARG_SVC_GATEWAY
  ip route add $ARG_CLIENT_SUBNET via $ARG_SVC_INGRESS
  ```
* Compose environment variables:
  ```bash
  - ARG_SVC_GATEWAY=198.19.64.245
  - ARG_CLIENT_SUBNET=10.1.10.0/24
  - ARG_SVC_INGRESS=198.19.64.7
  - INTERFACE=eth1
  ```
* Testing Suricata:
  * Reference: [Digital Ocean](https://www.digitalocean.com/community/tutorials/how-to-install-suricata-on-ubuntu-20-04)
  * Access the container shell:
    ```bash
    docker exec -it service-layer3 /bin/bash
    ```
  * Tail the Suricate fast log:
    ```bash
    tail -f /var/log/suricata/fast.log
    ```
  * Access the following URL:
    ```bash
    curl http://testmynids.org/uid/index.html
    ```
  * The output of the fast log will log for this request will look something like the below:
    ```bash
    Output 10/21/2021-18:35:54.950106  [**] [1:2100498:7] GPL ATTACK_RESPONSE id check returned root [**] [Classification: Potentially Bad Traffic] [Priority: 2] {TCP} 2600:9000:2000:4400:0018:30b3:e400:93a1:80 -> 2001:DB8::1:34628
    ```
  * Access the Suricata eve (JSON) log to show additional information on the detection:
    ```bash
    jq 'select(.alert .signature_id==2100498)' /var/log/suricata/eve.json
    ```
</details>


<details>
<summary><b>Explicit Proxy Service</b></summary>

* Ubuntu:bionic base image with Squid installation and routing configuration
* Routing configuration:
  ```bash
  ip route delete default
  ip route add default via $ARG_SVC_GATEWAY
  ip route add $ARG_CLIENT_SUBNET via $ARG_SVC_INGRESS
  ipaddr=$(ip addr show dev eth0 |egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.' | cut -d' ' -f2) && ip route add 8.8.8.8 via ${ipaddr}1
  echo "nameserver 8.8.8.8" > /etc/resolv.conf
  ```
* Compose environment variables:
  ```bash
  - TZ=UTC
  - UPDATE_EP=1
  - ARG_SVC_GATEWAY=198.19.96.245
  - ARG_CLIENT_SUBNET=10.1.10.0/24
  - ARG_SVC_INGRESS=198.19.96.7
  ```
* Squid Configuration (/etc/squid/squid.conf):
  ```bash
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
  ```
</details>


<details>
<summary><b>Transparent Proxy Service</b></summary>

* Ubuntu:bionic base image with Squid installation and routing configuration
* Routing configuration:
  ```bash
  sysctl net.ipv4.ip_forward=1
  sed -i -e 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 80 -j REDIRECT --to-port 3128

  ip route delete default
  ip route add default via $ARG_SVC_GATEWAY
  ip route add $ARG_CLIENT_SUBNET via $ARG_SVC_INGRESS
  ipaddr=$(ip addr show dev eth0 |egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.' | cut -d' ' -f2) && ip route add 8.8.8.8 via ${ipaddr}1
  echo "nameserver 8.8.8.8" > /etc/resolv.conf
  ```
* Compose environment variables:
  ```bash
  - TZ=UTC
  - UPDATE_EP=1
  - ARG_SVC_GATEWAY=198.19.98.245
  - ARG_CLIENT_SUBNET=10.1.10.0/24
  - ARG_SVC_INGRESS=198.19.98.7
  ```
* Squid Configuration (/etc/squid/squid.conf):
  ```bash
  http_access allow all
  http_port 3128
  
  coredump_dir /var/spool/squid
  cache deny all
  
  logfile_rotate 0
  logformat authheader %ts.%03tu %6tr %>a %Ss/%03>Hs %<st %rm %ru "%{X-Authenticated-User}>h" %Sh/%<a %mt
  access_log /var/log/squid/access.log authheader
  ```
</details>


<details>
<summary><b>ICAP Service</b></summary>

* Ubuntu 18.04 base image with c-icap and clamav installation
* Additional configuration in c-icap.conf to send "VIRUS" detections to the Syslog utility instance
* Compose environment variables:
  ```bash
  - ARG_LOCAL_SYSLOG=utility-syslogview
  ```
* C-ICAP configuration (/etc/c-icap/c-icap.conf):
  ```bash
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
  ```
* Testing c-icap and clamav:
  * Open the Syslog web UI
  * Access the following URL:
    ```bash
    curl -vk https://secure.eicar.org/eicar.com.txt --output -
    ```
</details>


<details>
<summary><b>TAP Service</b></summary>

* Ubuntu 20.04 base image with Suricata installation
* Compose environment variables:
  ```bash
  - INTERFACE=eth1
  ```
* Testing Suricata:
  * Reference: [Digital Ocean](https://www.digitalocean.com/community/tutorials/how-to-install-suricata-on-ubuntu-20-04)
  * Access the container shell:
    ```bash
    docker exec -it service-tap /bin/bash
    ```
  * Tail the Suricate fast log:
    ```bash
    tail -f /var/log/suricata/fast.log
    ```
  * Access the following URL:
    ```bash
    curl http://testmynids.org/uid/index.html
    ```
  * The output of the fast log will log for this request will look something like the below:
    ```bash
    Output 10/21/2021-18:35:54.950106  [**] [1:2100498:7] GPL ATTACK_RESPONSE id check returned root [**] [Classification: Potentially Bad Traffic] [Priority: 2] {TCP} 2600:9000:2000:4400:0018:30b3:e400:93a1:80 -> 2001:DB8::1:34628
    ```
  * Access the Suricata eve (JSON) log to show additional information on the detection:
    ```bash
    jq 'select(.alert .signature_id==2100498)' /var/log/suricata/eve.json
    ```
</details>


<details>
<summary><b>Wireshark TAP Service</b></summary>

* The Wireshark TAP service pulls down the latest ```lscr.io/linuxserver/wireshark:latest``` image and is included in the TAP service Compose file
* The web interface is accessible on port 3000
</details>


<details>
<summary><b>Webserver Utility</b></summary>

* Ubuntu 24.04 base image with OpenSSL 3.5 and NGINX 1.27.4 installations
* NGINX configuration (/opt/nginx/nginx.conf):
  ```bash
  user  www-data;
  worker_processes  auto;
  
  error_log  /var/log/nginx/error.log notice;
  pid        /var/run/nginx.pid;
  
  events {
      worker_connections  1024;
  }
  http {
      server {
          listen                  0.0.0.0:80;
          server_name             webserver.local;
          location ./images/ {
              root                /var/www/site/html/images;
          }
          location / {
              root                /var/www/site/html;
              index               index.html;
              include             /opt/nginx/mime.types;
          }
      }
      server {
          listen                  0.0.0.0:443 ssl;
          server_name             webserver.local;
          ssl_certificate         /etc/server.crt;
          ssl_certificate_key     /etc/server.key;
          location ./images/ {
              root                /var/www/site/html/images;
          }
          location / {
              root                /var/www/site/html;
              index               index.html;
              include             /opt/nginx/mime.types;
          }
      }
      server {
          listen                  0.0.0.0:444 ssl;
          ssl_certificate         /etc/server.crt;
          ssl_certificate_key     /etc/server.key;
          ssl_protocols           TLSv1.3;
          ssl_ecdh_curve          X25519MLKEM768;
  
          location / {
              default_type text/html;
              return 200 "<html><head><title>PQC Test Success!</title></head><body><H2>PQC Test Success!</H1><p><b>Negotiated Protocol</b>: \$ssl_protocol </p><p><b>Negotiated Cipher</b>: \$ssl_cipher </p><p><b>Negotiated Curve</b>: \$ssl_curve </p><p><b>Supported Curves</b>: \$ssl_curves </p></body></html>";
          }
      }
  }
  ```
</details>


<details>
<summary><b>Juiceshop Utility</b></summary>

* The Juiceshop Utility pulls down the latest ```bkimminich/juice-shop``` image
* The web interface is accessible on port 3000, HTTP
</details>


<details>
<summary><b>Syslog Utility</b></summary>

* The Syslog Utility pulls down the latest ```pierredavidbelanger/raftman``` image
* The web interface is accessible on port 8282, HTTP
</details>


<details>
<summary><b>Guacamole Utility</b></summary>

* guacamole/guacd 1.6.0 base image with Tomcat, Postgres, and Guacamole client installations
* Compose environment variables
  ```bash
  - ARG_RDP_HOST=10.1.1.4      ## IP address of the RDP host
  - ARG_RDP_PORT=3389          ## RDP listening port of the RDP host
  - ARG_RDP_USER=student       ## Username to use to log into the RDP host
  - ARG_RDP_PASS=agility       ## Password to use to log into the RDP host
  - ARG_GUAC_USER=user         ## Username to use to log into Guacamole (can be anything you want)
  - ARG_GUAC_PASS=user         ## Password for the Guacamole user (can be anything you want)
  ```
* The web interface is accessible on port 8080, HTTP
</details>

