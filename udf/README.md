# SSL Orchestrator Consolidated Services Architecture (UDF Version)
A Docker Compose configuration to create all of the SSLO security services on a single Ubuntu 18.04 instance, to both simplify and dramatically reduce resource utlization in a virtual environment.

### About
This Docker Compose configuration supports the **F5 UDF** demo environment, which itself supports 802.1Q VLAN tags. This also reduces the number of physical interfaces and connections required. The Docker Compose file contains all of the layer 3 services (ICAP, explicit proxy, layer 3 service, and web servers). Layer 2 and TAP services are defined directly on the host system and described in the "layer2-tap-config" readme file.

#### Update
- Now includes a **Owasp Juice Shop** for AWAF vulnerability testing.

- Now includes a **Guacamole** instance for web-based RDP connections into RDP hosts.

### Installation / Instructions
Perform the following steps to create the consolidated services architecture on an Ubuntu 18.04 (server) VM. 

Minimum requirements:
- docker >= 20.10
- docker-compose >= 1.29

-------------------

**Note that connections to inline services in this architecture is now different than in original SSLO UDF blueprints.** 

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
    $ sudo apt update
    $ curl -fsSL https://get.docker.com -o get-docker.sh
    $ sudo sh get-docker.sh
    $ sudo usermod -aG docker ${USER}
    ```
  
    Logout and back in, and then install the latest version of docker-compose:
  
    ```
    $ sudo apt-get install python-pip jq
    $ VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | jq .name -r)
    $ DESTINATION=/usr/local/bin/docker-compose
    $ sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
    $ sudo chmod 755 $DESTINATION
    ```

- **Step 4**: Download the docker-compose YAML and config files:

    ```
    $ git clone https://github.com/kevingstewart/sslo-consolidated-services.git
    $ cd sslo-consolidated-services/udf/
    ```

- **Step 5**: Identify the interface on the Ubuntu VM to anchor all of the layer 3 services, and then update the docker-compose YAML file accordingly. To find the interface, use this command:

    `$ lshw -c network`
    
    Map the '**serial**' value in the output to the MAC address in UDF under the VM's Subnet tab, and then find the corresponding '**logical name**' value (ex. ens6). Edit the configuration file, and under the "**networks**:' section at the bottom, change the interface names accordingly (multiple locations). Do not modify the VLAN tag value (number after the dot - ex. ens6.40). Then enable the corresponding interface(s) by modifying netplan:
    
    `$ sudo vi /etc/netplan/50-cloud-init-yaml`
    
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
    
    `$ sudo netplan apply`

- **Step 6**: Set the following as executable:
  
  ```
  sudo chmod -R +x configs/webrdp/init
  ```

- **Step 7**: Initiate the Docker Compose. Within the *./sslo-consolidates-services/udf* folder, execute the following to build the docker containers:

    `docker-compose -f docker-services-all.yaml up -d`
    
    You should see each of the containers pull down objects. Once complete, verify the containers are running:
    
    `docker ps`
    
    Your output should look something like this:
    
    ```
    CONTAINER ID   IMAGE                           COMMAND                  CREATED             STATUS                       PORTS                                                                      NAMES
    62def421cb6d   guacamole/guacamole             "/opt/guacamole/bin/…"   About an hour ago   Up About an hour             0.0.0.0:8080->8080/tcp, :::8080->8080/tcp                                  guacamole_compose
    61d0daf33852   guacamole/guacd                 "/bin/sh -c '/usr/lo…"   About an hour ago   Up About an hour (healthy)   4822/tcp                                                                   guacd_compose
    bae66a4cd871   httpd:2.4                       "sh /srv/webserver-i…"   About an hour ago   Up About an hour             0.0.0.0:80->80/tcp, :::80->80/tcp, 0.0.0.0:443->443/tcp, :::443->443/tcp   apache
    b38ebd93928a   datadog/squid                   "/sbin/entrypoint.sh…"   About an hour ago   Up About an hour             0.0.0.0:3128->3128/tcp, :::3128->3128/tcp                                  explicit-proxy
    3c149906cba2   postgres:13.4-buster            "docker-entrypoint.s…"   About an hour ago   Up About an hour             5432/tcp                                                                   postgres_guacamole_compose
    3514334adff4   nginx:alpine                    "/docker-entrypoint.…"   About an hour ago   Up About an hour             80/tcp, 0.0.0.0:8443->8443/tcp, :::8443->8443/tcp                          nginx
    68ccaaa17e1d   deepdiver/icap-clamav-service   "/entrypoint.sh"         About an hour ago   Up About an hour                                                                                        icap
    41a34f33c8e7   bkimminich/juice-shop           "/nodejs/bin/node /j…"   About an hour ago   Up About an hour             3000/tcp                                                                   juiceshop
    7cbba7dd10cd   nsherron/suricata               "sh /srv/layer3-init…"   About an hour ago   Up About an hour                                                                                        layer3
    ```

- **Step 8**: Configure SSL Orchestrator to use these services. 

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
  