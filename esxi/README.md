# SSL Orchestrator Consolidated Services Architecture (ESXi Version)
A Docker Compose configuration to create all of the SSLO security services on a single Ubuntu 20.04+ instance, to both simplify and dramatically reduce resource utlization in a virtual environment. This environment requires a total of three VM instances:
- F5 BIG-IP
- Client (Ubuntu/Linux or Windows)
- Server (Ubuntu - contains all of the security service functions)

### About
This Docker Compose configuration supports a **VMware vSphere ESXi** demo environment, which itself supports 802.1Q VLAN tags. This also reduces the number of physical interfaces and connections required. The Docker Compose file contains all of the layer 3 services (ICAP, explicit proxy, layer 3 service, and web servers). Layer 2 and TAP services are defined directly on the host system and described in the "layer2-tap-config" readme file.

#### Update
- Now includes a **Owasp Juice Shop** for AWAF vulnerability testing.


-------------------

### Minimum software requirements
This environment requires the following software minimums 

| Software                | Minimum |
|-------------------------|---------|
| vSphere/ESXi            | 6.5     |
| Docker                  | 20.10   |
| Docker-Compose          | 1.29    |
| Ubuntu                  | 20.04   |
| F5-BIG-IP               | 15.1.0  |

-------------------

### Virtualization Requirements
Use the following requirements to configure VM instances in ESXi

- **ESXi environment**
  - Minimums
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
      - Security: Promiscuous mode: Accept
      - Security: MAC address changes: Accept
      - Security: Forged transmits: Accept
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

- **BIG-IP VM instance**
  - Minimums
    - 4 vCPU
    - 2 Cores per socket (2 sockets)
    - 12 GB memory
    - 300 GB (IDE, thin provisioning is fine)
  - Network adapters (5 interfaces - all vmxnet3)
    - VM Network
     - Client Network
     - Layer 3 Network
     - L2 Service In Network
     - L2 Service Out Network
  - Software
    - BIG-IP 15.1 or higher (ISO or OVA install)
    - Required licensing
      - SSL Orchestrator 1GB VE (or higher VE)
    - Optional licensing
      - URL Filtering
      - IP Intelligence
      - APM - forward proxy authentication
      - SWG - SWG as a service
      - WAF - WAF as a service
      - AFM - DDoS/protocol protection
  - Configuration
    - Create these networks manually
      - Client VLAN - create an untagged VLAN for client traffic. This will be on the corresponding Client Network, no tag.
        - Self-IP: 10.1.10.100/24
      - Web VLAN - create a tagged VLAN for the internal web server traffic. This will be on the corresponding L3 Network interface, tag 80.
        - Self-IP: 192.168.100.100/24
      - ICAP VLAN - create a tagged VLAN for the ICAP security service. This will be on the corresponding L3 Network interface, tag 50.
        - Self-IP: 198.19.97.7/25   (subnet mask 255.255.255.128)
    - Create these web server pools
      - web-pool-https
        - 192.168.100.10:443
        - 192.168.100.11:443
        - 192.168.100.12:443
        - 192.168.100.13:443
      - web-pool-http
        - 192.168.100.10:80
        - 192.168.100.11:80
        - 192.168.100.12:80
        - 192.168.100.13:80
  - Configuration (automated) - change the interfaces to match your environment
    ```
    tmsh create net vlan client-vlan interfaces replace-all-with { 1.2 { untagged } }
    tmsh create net vlan dlp-vlan interfaces replace-all-with { 1.3 { tagged } } tag 50
    tmsh create net vlan web-vlan interfaces replace-all-with { 1.3 { tagged } } tag 80

    tmsh create net self client-self address 10.1.10.100/24 vlan client-vlan allow-service default
    tmsh create net self dlp-self address 198.19.97.7/25 vlan dlp-vlan allow-service default
    tmsh create net self web-self address 192.168.100.100/24 vlan web-vlan allow-service default

    tmsh create ltm pool web-http-pool monitor gateway_icmp members replace-all-with { 192.168.100.10:80 192.168.100.11:80 192.168.100.12:80 192.168.100.13:80 }
    tmsh create ltm pool web-https-pool monitor gateway_icmp members replace-all-with { 192.168.100.10:443 192.168.100.11:443 192.168.100.12:443 192.168.100.13:443 }

    ```


<br />

- **Security services instance**
  - Minimums
    - 2 vCPU
    - 8 GB memory
    - 30 GB (thin provisioning is fine)
  - Networking (5 interfaces)
    - VM Network
    - Layer 3 Network
    - L2 Service In Network
    - L2 Service Out Network
  - Software
    - OS: Ubuntu >= 20.04
      
      https://releases.ubuntu.com/22.10/ubuntu-22.10-live-server-amd64.iso?_ga=2.62785068.1880661055.1681226278-948822312.1681226278
      
    - Docker >= 20.10
    - Docker-Compose >= 1.29
  - Installation and configuration
    - Install updates and minimum software requirements
      ```
      sudo apt-get update && sudo apt-get upgrade -y && sudo apt install -y git bridge-utils tcpdump net-tools jq
      ```
    - Configure interfaces
      - *List the interfaces and match to the MAC addresses assigned in VMware to correlate the connected vSwitches. They won't necessarily be in the order they were defined. Remember these for later.*
        ```
        lshw -c network |egrep 'logical name|serial'
        ```

      - *Modify the netplan config accordingly - disable all dhcp and add the L2 in and L2 out interfaces to a bridge network*
        ```
        sudo vi /etc/netplan/00-installer-config.yaml
        ```
        *In the below example, ens160 is the VM Network, ens161 is the L3 Network, and ens192 and ens224 are the L2 In and L2 Out Networks, respectively.*
        ```
        network:
          ethernets:
            ens160:
              addresses:
              - 172.16.1.130/23
              nameservers:
                addresses:
                - 172.16.0.1
              routes:
              - to: default
                via: 172.16.0.1
            ens161:
              dhcp4: false
              dhcp6: false
            ens192:
              dhcp4: false
              dhcp6: false
            ens224:
              dhcp4: false
              dhcp6: false

          bridges:
            br0:
              interfaces:
              - ens192
              - ens224
              dhcp4: false
              dhcp6: false

          version: 2
        ```
      - *Apply the netplan config and disable iptables processing on the bridge interface*
        ```
        sudo netplan apply

        echo 0 | sudo tee /proc/sys/net/bridge/bridge-nf-call-arptables
        echo 0 | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables
        echo 0 | sudo tee /proc/sys/net/bridge/bridge-nf-call-ip6tables

        sudo tee -a /etc/sysctl.conf <<EOF
        net.bridge.bridge-nf-call-ip6tables = 0
        net.bridge.bridge-nf-call-iptables = 0
        net.bridge.bridge-nf-call-arptables = 0
        EOF

        sudo sysctl -p /etc/sysctl.conf
        ```

      - *Reboot*
        ```
        sudo reboot
        ```

    - Install Docker
      ```
      curl -fsSL https://get.docker.com -o get-docker.sh
      sudo sh get-docker.sh
      sudo usermod -aG docker ${USER}
      <log out and back in again>
      docker run hello-world
      ```

    - Install Docker-Compose
      ```
      VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | jq .name -r)
      DESTINATION=/usr/local/bin/docker-compose
      sudo curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $DESTINATION
      sudo chmod 755 $DESTINATION
      ```
    - Clone the consolidated-services repository
      ```
      git clone https://github.com/kevingstewart/sslo-consolidated-services
      ```
    - Adjust the container interfaces
      - *change to the consolidated-services esxi folder*
        ```
        cd sslo-consolidated-services/esxi/
        ```

      - *edit the .env file and change the L3NET variable to point to the correct L3 network Ubuntu interface. The docker-compose file uses this environment variable for the L3 network.*
        ```
        vi .env

        L3NET=ens161
        ```

    - Deploy the containers
      ```
      docker-compose -f docker-services-all.yaml up -d
      ```

    - Verify running containers - 6 containers should be running with no errors
      ```
      docker ps
      ```

<br />

- **Client instances**
  - Minimums
    - 2 vCPU
    - 8 GB memory
    - 30 GB (thin provisioning is fine)
  - Networking
    - VM network
      - Address: local IP subnet
      - DNS: local DNS
      - No gateway
    - Client network
      - Address: 10.1.10.50/24
      - Gateway: BIG-IP Client Network self-IP (10.1.10.100)
  - Software OS
    - OS options
      - Ubuntu >= 20.04
      - Windows
    - Browsers (multiple)
    - Curl (command line web client)

<br />

- **SSL Orchestrator configuration**: Make note of the following networks for use in building security services
  - Layer 2 service
    - L2 in - uses a dedicated VMware vSwitch, no VLAN tag
    - L2 out - uses a dedicated VMware vSwitch, no VLAN tag
  - Layer 3 service
    - Layer 3 in - uses the L3 Network interface, VLAN tag 60, IP: 198.19.64.30/25
    - Layer 3 out - uses the L3 Network interface, VLAN tag 70, IP: 198.19.64.130/25
  - Explicit proxy service
    - Explicit Proxy in - uses the L3 Network interface, VLAN tag 30, IP: 198.19.96.30/25, port: 3128
    - Explicit Proxy out - uses the L3 Network interface, VLAN tag 40, IP: 198.19.96.130/25
  - ICAP service
    - ICAP - uses the L3 Network interface, VLAN tag 50, IP: 198.19.97.50, port: 1344


-------------------
-------------------
-------------------


**Please see *sslo-configuration-info.md* for information on setting up SSL Orchestrator with these new consolidated services**

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

