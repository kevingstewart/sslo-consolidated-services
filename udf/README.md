# SSL Orchestrator Consolidated Services Architecture (UDF Version)
A Docker Compose configuration to create all of the SSLO security services on a single Ubuntu 18.04 instance, to both simplify and dramatically reduce resource utlization in a virtual environment.

### About
This Docker Compose configuration supports the **F5 UDF** demo environment, which itself supports 802.1Q VLAN tags. This also reduces the number of physical interfaces and connections required.

### Installation / Instructions
Perform the following steps to create the consolidated services architecture on an Ubuntu 18.04 (server) VM. 

- **Step 1**: Ensure that the Ubuntu instance minimally binds the following interfaces in the SSL Orchestrator UDF instance:
  
  - **DLP VLAN** - used as the single consolidated interface for all layer 3 security services (on separate 802.1Q tagged VLANs).
  - **L2 Inbound VLAN** - used to connect to the L2 service inbound interface.
  - **L2 Outbound VLAN** - used to connect to the L2 service outbound interface.
  - **TAP VLAN** - used to connect to the TAP service interface.

- **Step 2**: Open an SSH connection to the Ubuntu VM and create a new empty directory to work from.

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
    $ wget https://github.com/kevingstewart/sslo-consolidated-services/archive/main.zip
    $ unzip main.zip
    $ cd sslo-consolidated-services-main/udf
    ```

- **Step 5**: Identify the interface on the Ubuntu VM to anchor all of the layer 3 services, and then update the docker-compose YAML file accordingly. To find the interface, use this command:

    `$ lshw -c network`
    
    Map the '**serial**' value in the output to the MAC address in UDF under the VM's Subnet tab, and then find the corresponding '**logical name**' value (ex. ens6). Edit the configuration file, and under the "**networks**:' section at the bottom, change the interface names accordingly. Do no modify the VLAN tag value (number after the dot - ex. ens8.40). Then enable the corresponding interface(s) by modifying netplan:
    
    `$ sudo vi /etc/netplan/50-cloud-init-yaml`
    
    Add you interface(s) with '*dhcp4: false*'. Example:
    
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

- **Step 6**: Initiate the Docker Compose. Within the *./sslo-consolidates-services/udf* folder, execute the following to build the docker containers:

    `docker-compose -f docker-services-all.yaml up -d`
    
    You should see each of the containers pull down objects. Once complete, verify the containers are running:
    
    `docker ps`
    
    Your output should look something like this:
    
    ```
    CONTAINER ID   IMAGE                           COMMAND                  CREATED         STATUS         PORTS                    NAMES
    d09e121dc3cd   datadog/squid                   "/sbin/entrypoint.sh…"   9 seconds ago   Up 3 seconds   0.0.0.0:3128->3128/tcp   explicit-proxy
    2b5a9886454b   nsherron/suricata               "sh /srv/layer3-init…"   9 seconds ago   Up 4 seconds                            layer3
    e02bb8a23a2d   deepdiver/icap-clamav-service   "/entrypoint.sh"         9 seconds ago   Up 5 seconds                            icap
    ```

- **Step 7**: Configure SSL Orchestrator to use these services. 

    - Create a DLP VLAN, tag 50 (tagged).
    - Create a DLP self-IP: 198.19.97.7 msak 255.255.255.128
    
    In the SSL Orchestrator configuration, create the following security services:
    
    - ICAP: 
      - ICAP Devices: 198.19.97.50:1344
      - Request Modification URI Path: /avscan
      - Response Modification URI Path: /avscan
      - Preview Max Length: 1048576
    
    - Layer3:
    
    - Proxy:
    


