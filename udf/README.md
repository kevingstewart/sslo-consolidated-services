# SSL Orchestrator Consolidated Services Architecture (UDF Version)
A Docker Compose configuration to create all of the SSLO security services on a single Ubuntu 18.04 instance, to both simplify and dramatically reduce resource utlization in a virtual environment.

### About
This Docker Compose configuration supports the **F5 UDF** demo environment, which itself supports 802.1Q VLAN tags. This also reduces the number of physical interfaces and connections required.

### Installation / Instructions
Perform the following steps to create the consolidated services architecture on an Ubuntu 18.04 VM. 

- **Step 1**: Ensure that the Ubuntu instance minimally binds the following interfaces in the SSL Orchestrator UDF instance:
  
  - **Client VLAN** - used by the client (desktop) to connect to SSLO for forward proxy topologies.
  - **Outbound VLAN** - used by the client (desktop) to connect to SSLO for reverse proxy topologies.
  - **DLP VLAN** - used as the single consolidated interface for all layer 3 security services (on separate 802.1Q tagged VLANs).
  - **L2 Inbound VLAN** - used to connect to the L2 service inbound interface.
  - **L2 Outbound VLAN** - used to connect to the L2 service outbound interface.
  - **TAP VLAN** - used to connect to the TAP service interface.

- **Step 2**: Open an SSH connection to the Ubuntu VM and create a new empty directory to work from.

- **Step 3**: Install Docker and Docker-Compose:

- **Step 4**: Download the docker-compose YAML and config files:

  `$ wget https://github.com/kevingstewart/sslo-consolidated-services/archive/main.zip`

  `$ unzip main.zip`

  `$ cd sslo-consolidated-services-main/udf`

- **Step 5**: 

- **Step 6**: 

- **Step 7**: 


