## SSL Orchestrator Configuration

The interfaces used in this new consolidated architecture are different than those used in the original SSL Orchestrator UDF blueprints. Please see below for the correct connectivity information.

----------------------

In the SSL Orchestrator configuration, create the following security services:

- **ICAP Service**: 
  - ICAP Devices: 198.19.97.50:1344
  - Request Modification URI Path: /avscan
  - Response Modification URI Path: /avscan
  - Preview Max Length: 1048576
  - Note: The SSL Orchestrator "Lite" UDF blueprint has the ICAP VLAN and self-IP already defined.

- **Layer 3 Service**:
  - Auto Manage Addresses: enabled
  - To Service Configuration:
    - Self-IP: 198.19.64.7/25
    - Create new VLAN on interface **(ESXi L3 Network interface) - Tag 60**
  - Security Devices:
    - 198.19.64.30
  - From Service Configuration:
    - Self-IP: 198.19.64.245/25
    - Create new VLAN on interface **(ESXi L3 Network interface) - Tag 70**

- **Explicit Proxy Service**:
  - Auto Manage Addresses: enabled
  - To Service Configuration:
    - Self-IP: 198.19.96.7/25
    - Create new VLAN on interface **(ESXi L3 Network interface) - Tag 30**
  - Security Devices:
    - 198.19.96.30
  - From Service Configuration:
    - Self-IP: 198.19.96.245/25
    - Create new VLAN on interface **(ESXi L3 Network interface) - Tag 40**

- **Layer 2 Service**:
  - To Service Configuration:
    - To-service: interface **(ESXi L2 In Network interface)**
  - From Service Configuration:
    - From-service: interface **(ESXi L2 Out Network interface)**

- **TAP Service**:
  - To Service Configuration:
    - To-service: interface **(ESXi TAP Network interface)**

- **Web Servers**:
  - 192.168.100.10 (supports http:80 and https:443)
  - 192.168.100.11 (supports http:80 and https:443)
  - 192.168.100.12 (supports http:80 and https:443)
  - 192.168.100.13 (supports http:80 and https:443)

- **Juiceshop**:
  - Pool: 192.168.100.200:443 (requires server SSL)

<br />

----------------------

### Testing

There are multiple options for showing decrypted traffic flowing across the security services:

- tcpdump on the BIG-IP service VLANs
- tcpdump on the service interfaces inside the service containers

The latter is achieved by accessing the shell of each container. Do this from a shell on the consolidated services Ubuntu instance:

- Inline L3 service
  ```
  docker exec -it layer3 /bin/bash
  tcpdump -lnni eth1 not icmp and not arp
  tcpdump -lnni eth1 -Xs0 not icmp and not arp
  ```

- Inline HTTP service
  ```
  docker exec -it explicit-proxy /bin/bash
  tcpdump -lnni eth1 not icmp and not arp
  tcpdump -lnni eth1 -Xs0 not icmp and not arp
  ```

Inline L2 and TAP services are accessible directly from the consolidated services VM host:

- Inline L2
  ```
  sudo tcpdump -lnni ens161 -Xs0 not icmp and not arp
  ```




