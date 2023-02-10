# IN DEVELOPMENT

# SSL Orchestrator Consolidated Services Architecture (ESXi Version)
A Docker Compose configuration to create all of the SSLO security services on a single Ubuntu 18.04+ instance, to both simplify and dramatically reduce resource utlization in a virtual environment.

### About
This Docker Compose configuration supports a **VMware vSphere ESXi** demo environment, which itself supports 802.1Q VLAN tags. This also reduces the number of physical interfaces and connections required. The Docker Compose file contains all of the layer 3 services (ICAP, explicit proxy, layer 3 service, and web servers). Layer 2 and TAP services are defined directly on the host system and described in the "layer2-tap-config" readme file.

#### Update
- Now includes a **Owasp Juice Shop** for AWAF vulnerability testing.

- Now includes a **Guacamole** instance for web-based RDP connections into RDP hosts.

- Now includes a **Splunk** instance for SSL Orchestrator forensic logging.

-------------------

### Installation / Instructions
Perform the following steps to create the consolidated services architecture on an Ubuntu 18.04 (server) VM. 

Minimum requirements:
- vSphere/ESXi += 6.5
- docker >= 20.10
- docker-compose >= 1.29

-------------------

### Virtualization Requirements
Use the following requirements to configure VM instances in ESXi

- **ESXi environment**
  - Minimum requirements
    - vSphere/esxi version: >= 6.5
    - Memory: >= 32Gb
    - Storage: >= 1 TB
  - Networking
    - VM Network (vSwitch attached to host network)
      - VLAN ID: None (0)
    - Client Network (local vSwitch  - no adapters)
      - VLAN ID: All (4096)
    - L3 Service Network (local vSwitch  - no adapters)
      - VLAN ID: All (4096)
    - L2 Service In Network (local vSwitch  - no adapters)
      - VLAN ID: None (0)
      - Security: Promiscuous mode: Accept
      - Security: MAC address changes: Accept
      - Security: Forged transmits: Accept
    - L2 Service Out Network (local vSwitch  - no adapters)
      - VLAN ID: None (0)
      - Security: Promiscuous mode: Accept
      - Security: MAC address changes: Accept
      - Security: Forged transmits: Accept

<br />

- **BIG-IP VM instances**
  - 4 CPU
  - 2 Cores per socket (2 sockets)
  - 12 GB memory
  - 300 GB (IDE, thin provisioning is fine)
  - Network adapters (all vmxnet3)
    - VM Network
    - Client Network
    - Layer 3 Network
    - L2 Service In Network
    - L2 Service Out Network

<br />

- **Security services instances**
  - 2 CPU
  - 8 GB memory
  - 60 GB (thin provisioning is fine)
  - Networking:
    - VM Network
    - Client Network
    - Layer 3 Network
    - L2 Service In Network
    - L2 Service Out Network
  - Software:
    - OS: Ubuntu >= 18.04
    - Docker >= 20.10
    - Docker-Compose >= 1.29

<br />

- **Client instances**
  - 2 CPU
  - 4 GB memory
  - 30 GB (thin provisioning is fine)
  - Networking:
    - VM Network
    - Client Network
  - Software:
    - OS: Ubuntu >= 18.04 (or Windows, other desktop OS)
    - Chrome, Firefox
    - Curl
    - OpenSSL

-------------------

**Please see *sslo-configuration-info.md* for information on setting up SSL Orchestrator with these new consolidated services**

-------------------

- **Step 1**: Ensure that the Ubuntu instance minimally binds the following interfaces in the SSL Orchestrator UDF instance:
  
  - **DLP VLAN** - used as the single consolidated interface for all layer 3 security services (on separate 802.1Q tagged VLANs).
  - **L2 Inbound VLAN** - used to connect to the L2 service inbound interface.
  - **L2 Outbound VLAN** - used to connect to the L2 service outbound interface.
  - **TAP VLAN** - used to connect to the TAP service interface.

- **Step 2**: Open an SSH connection to the Ubuntu VM and create a new empty directory to work from.

    ```
    mkdir ~/build
    cd ~/build
    ```

- **Step 3**: Install Docker and Docker-Compose:

    ```
    sudo apt update
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker ${USER}
    ```
  
    Logout and back in, and then install the latest version of docker-compose:
  
    ```
    sudo apt-get install python-pip jq
    VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | jq .name -r)
    DESTINATION=/usr/local/bin/docker-compose
    sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
    sudo chmod 755 $DESTINATION
    ```

- **Step 4**: Download the docker-compose YAML and config files:

    ```
    git clone https://github.com/kevingstewart/sslo-consolidated-services.git
    cd sslo-consolidated-services/udf/
    sudo chmod -R +x configs/webrdp/init/
    ```

- **Step 5**: Identify the interface on the Ubuntu VM to anchor all of the layer 3 services, and then update the docker-compose YAML file accordingly. To find the interface, use this command:

    ```
    lshw -c network
    ```
    
    Map the '**serial**' value in the output to the MAC address in UDF under the VM's Subnet tab, and then find the corresponding '**logical name**' value (ex. ens6). Edit the configuration file, and under the "**networks**:' section at the bottom, change the interface names accordingly (multiple locations). Do not modify the VLAN tag value (number after the dot - ex. ens6.40). Then enable the corresponding interface(s) by modifying netplan:
    
    ```
    sudo vi /etc/netplan/50-cloud-init-yaml
    ```
    
    Add your interface(s) with '*dhcp4: false*'. Example:
    
    ```
    network:
    version: 2
    ethernets:
        ens5:
            dhcp4: true
        ens6:
            dhcp4: false
    ```
    
    And then re-apply netplan:
    
    ```
    sudo netplan apply
    ```

- **Step 6**: Initiate the Docker Compose. Within the *./sslo-consolidates-services/udf* folder, execute the following to build the docker containers:

  ```
  docker-compose -f docker-services-all.yaml up -d
  ```
    
  You should see each of the containers pull down objects. Once complete, verify the containers are running:

  ```  
  docker ps
  ```
    
  Your output should look something like this:
    
  ```
  CONTAINER ID   IMAGE                           COMMAND                  CREATED          STATUS                    PORTS                                                                            NAMES
  c8f206075a60   guacamole/guacamole             "/opt/guacamole/bin/…"   39 minutes ago   Up 38 minutes             0.0.0.0:8080->8080/tcp, :::8080->8080/tcp                                        guacamole_compose
  f13e3d20b611   bkimminich/juice-shop           "/nodejs/bin/node /j…"   39 minutes ago   Up 39 minutes             3000/tcp                                                                         juiceshop
  5eb56cc827bb   nsherron/suricata               "sh /srv/layer3-init…"   39 minutes ago   Up 38 minutes                                                                                              layer3
  76b599c24009   deepdiver/icap-clamav-service   "/entrypoint.sh sh /…"   39 minutes ago   Up 39 minutes                                                                                              icap
  69dfc17176c2   postgres:13.4-buster            "docker-entrypoint.s…"   39 minutes ago   Up 39 minutes             5432/tcp                                                                         postgres_guacamole_compose
  9011436c8c74   sameersbn/squid:3.5.27-2        "/sbin/entrypoint.sh…"   39 minutes ago   Up 38 minutes             0.0.0.0:3128->3128/tcp, :::3128->3128/tcp                                        explicit-proxy
  25d9b1d410d4   httpd:2.4                       "sh /srv/webserver-i…"   39 minutes ago   Up 39 minutes             0.0.0.0:80->80/tcp, :::80->80/tcp, 0.0.0.0:443->443/tcp, :::443->443/tcp         apache
  c20883c0ca0d   nginx:alpine                    "/docker-entrypoint.…"   39 minutes ago   Up 39 minutes             80/tcp, 0.0.0.0:8443->8443/tcp, :::8443->8443/tcp                                nginx
  705b2f7bc697   guacamole/guacd                 "/bin/sh -c '/usr/lo…"   39 minutes ago   Up 39 minutes (healthy)   4822/tcp                                                                         guacd_compose
  ```

- **Step 7**: Configure SSL Orchestrator to use these services. 

    - Create the DLP VLAN on interface 1.3 tag 50 (tagged).
      
      ```
      tmsh create net vlan dlp-vlan interfaces replace-all-with { 1.3 { tagged } } tag 50
      ```
   
    - Create the DLP self-IP: 198.19.97.7 mask 255.255.255.128
    
      ```
      tmsh create net self dlp-self address 198.19.97.7/25 vlan dlp-vlan allow-service default
      ```
    
    - Create the webserver VLAN on interface 1.3 tag 80 (tagged)
    
      ```
      tmsh create net vlan web-vlan interfaces replace-all-with { 1.3 { tagged } } tag 80
      ```
    
    - Create the webserver self-IP: 192.168.100.100 mask 255.255.255.0
    
      ```
      tmsh create net self web-self address 192.168.100.100/24 vlan web-vlan allow-service default
      ```
    
    - Create an HTTP web server pool:
      - 192.168.100.10:80
      - 192.168.100.11:80
      - 192.168.100.12:80
      - 192.168.100.13:80
      
      ```
      tmsh create ltm pool web-http-pool monitor gateway_icmp members replace-all-with { 192.168.100.10:80 192.168.100.11:80 192.168.100.12:80 192.168.100.13:80 }
      ```
      
    - Create an HTTPS web server pool:
      - 192.168.100.10:443
      - 192.168.100.11:443
      - 192.168.100.12:443
      - 192.168.100.13:443
      
      ```
      tmsh create ltm pool web-https-pool monitor gateway_icmp members replace-all-with { 192.168.100.10:443 192.168.100.11:443 192.168.100.12:443 192.168.100.13:443 }
      ```
-------------------

- **Extra: Rebuilding from scratch**: In the event that things going terribly wrong, a script has been provided that will completely delete all containers and images, perform a total Docker system flush, then re-start the Docker Compose environment.

  ```
  ./security-services-rebuild.sh
  ```

-------------------

- **Extra: Juice Shop**: Implement Juice Shop for web vulnerability testing. Juice Shop is a modern insecure web application for testing web security frameworks. You can create an inbound application mode SSL Orchestrator topology that points to the Juice Shop instance, and insert your WAF of choice to test functionality inside the decrypted service chain. To implement Juice Shop:

  - Create a Juice Shop pool at 192.168.10.200:443 (requires server SSL)
  - Create an inbound application mode topology or existing applicaition topology, and apply the Juice Shop pool.
  - Insert a WAF security product into the decrypted SSL Orchestrator service chain.
  - Alternately, create a normal reverse proxy application virtual server, including the Juice Shop pool and server SSL profile. Attach the existing application policy to the VIP.

-------------------

- **Extra: Guacamole**: Access the client desktop with Web-based RDP. Guacamole is included to provide RDP access to internal desktop resources. Access it using the following: 

  ```
  http://[IP-address]:8080/guacamole
  ```

  - Admin control is accessible with the following credentials: `guacadmin:guacadmin`, 
  - A separate user account is pre-created with access to the client desktop, with credentials: `user:user`

  The current Guacamole PostgreSQL initialization script pre-creates a `Client Desktop` at 10.1.1.5:3389, and assigns permissions to the account `user` to access this desktop. To change the desktop parameters, edit the initdb.sql file in the ./configs/webrdp/init folder **before** the first run of the Docker Compose file. 
  
  ```
  set session my.vars.rdpname = 'Client Desktop';
  set session my.vars.rdphost = '10.1.1.5';
  set session my.vars.rdpuser = 'student';
  set session my.vars.rdppass = 'agility';
  ```

  If the Docker-Compose has already been started at least once, you'll need to delete the guacamole folder by performing the following steps:

  ```  
  docker-compose -f docker-services-all.yaml down
  sudo rm -rm ./configs/webrdp/data/guacamole/
  docker-compose -f docker-services-all.yaml up -d
  ```

  To create an Access Method assignment in UDF:
  - Label: WebRDP
  - Protocol: HTTPS
  - Instance Access: select the management IP address
  - Instance Port: 8080
  - SSL: disabled
  - Unauthenticated: enabled
  - Path: guacamole

-------------------

**Note**: If you get an error launching the Guacamole UI, you likely also need to update Docker-Compose. This environment minimally requires docker-compose version 1.29 and higher.

```
docker-compose version
sudo apt update
sudo apt upgrade
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose version
```

-------------------

- **Extra: Splunk**: The Splunk instance will come up with an empty configuration, and no objects are build on the BIG-IP to send logs to it. To configure this, refer to the following instructions: https://github.com/kevingstewart/f5_sslo_telemetry/tree/main/observability-tools/splunk.


