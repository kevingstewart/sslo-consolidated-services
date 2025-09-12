## SSL Orchestrator Configuration

Please see below for the correct connectivity information in the SSL Orchestrator UDF Lab.

----------------------

In the BIG-IP UI, create the following VLANs and corresponding Self-IPs:

| Service      | Interface | Tag | Self-IP          |
|--------------|-----------|-----|------------------|
| Web Services | 1.2       | 80  | 192.168.100.7/24 |
| ICAP Service | 1.2       | 50  | 198.19.97.7/25   |

In the SSL Orchestrator configuration, create the following security services:

- **ICAP Service**: 
  - ICAP Devices: 198.19.97.50:1344
  - Request Modification URI Path: /avscan
  - Response Modification URI Path: /avscan
  - Preview Max Length: 1048576

- **Layer 3 Service**:
  - Auto Manage Addresses: enabled
  - To Service Configuration:
    - Self-IP: 198.19.64.7/25
    - Create new VLAN on interface **1.2 tag 60**
  - Security Devices:
    - 198.19.64.30
  - From Service Configuration:
    - Self-IP: 198.19.64.245/25
    - Create new VLAN on interface **1.2 tag 70**

- **Explicit Proxy Service**:
  - Auto Manage Addresses: enabled
  - To Service Configuration:
    - Self-IP: 198.19.96.7/25
    - Create new VLAN on interface **1.2 tag 30**
  - Security Devices:
    - 198.19.96.30
  - From Service Configuration:
    - Self-IP: 198.19.96.245/25
    - Create new VLAN on interface **1.2 tag 40**

- **Transparent Proxy Service**:
  - Auto Manage Addresses: disabled
  - To Service Configuration:
    - Self-IP: 198.19.98.7/25
    - Create new VLAN on interface **1.2 tag 10**
  - Security Devices:
    - 198.19.98.30
  - From Service Configuration:
    - Self-IP: 198.19.98.245/25
    - Create new VLAN on interface **1.2 tag 20**
   
- **Layer 2 Service**:
  - To Service Configuration:
    - To-service: interface **1.4**
  - From Service Configuration:
    - From-service: interface **1.5**

- **TAP Service**:
  - To Service Configuration:
    - To-service: interface **1.3 tag 1000**

- **Wireshark TAP Service**:
  - To Service Configuration:
    - To-service: interface **1.3 tag 1001**

- **Web Servers**:
  - Pool: 192.168.100.10 port 80 (HTTP)
  - Pool: 192.168.100.10 port 443 (HTTPS)

- **Juiceshop**:
  - Pool: 192.168.100.20 port 3000 (HTTP)
 
