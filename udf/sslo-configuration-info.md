## SSL Orchestrator Configuration

The interfaces used in this new consolidated architecture are different than those used in the original SSL Orchestrator UDF blueprints. Please see below for the correct connectivity information.

----------------------

In the SSL Orchestrator configuration, create the following security services:

- **ICAP**: 
  - ICAP Devices: 198.19.97.50:1344
  - Request Modification URI Path: /avscan
  - Response Modification URI Path: /avscan
  - Preview Max Length: 1048576
  - Note: The SSL Orchestrator "Lite" UDF blueprint has the ICAP VLAN and self-IP already defined.

- **Layer3**:
  - Auto Manage Addresses: enabled
  - To Service Configuration:
    - Self-IP: 198.19.64.7/25
    - Create new VLAN on interface **1.3 tag 60**
  - Security Devices:
    - 198.19.64.30
  - From Service Configuration:
    - Self-IP: 198.19.64.245/25
    - Create new VLAN on interface **1.3 tag 70**

- **Explicit Proxy**:
  - Auto Manage Addresses: enabled
  - To Service Configuration:
    - Self-IP: 198.19.96.7/25
    - Create new VLAN on interface 1.3 tag 30
  - Security Devices:
    - 198.19.96.30
  - From Service Configuration:
    - Self-IP: 198.19.96.245/25
    - Create new VLAN on interface 1.3 tag 40

- **Layer2**:
  - To Service Configuration:
    - To-service: interface 1.4
  - From Service Configuration:
    - From-service: interface 1.5

- **TAP**:
  - To Service Configuration:
    - To-service: interface 1.6


