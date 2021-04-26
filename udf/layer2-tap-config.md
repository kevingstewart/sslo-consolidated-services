## Configuration settings for SSLO layer 2 and TAP security services.
Layer 2 networking inside containers is non-trivial, so this configuration installs the necessary network and security services on the host VM for layer 2 and TAP. All layer 3 services are otherwise installed via the Docker Compose.

-------------------

**Note that connections to inline services in this architecture is now different than in original SSLO UDF blueprints.** 

**Please see *sslo-configuration-info.md* for information on setting up SSL Orchestrator with these new consolidated services**

-------------------

- **Layer 2 Service**: This configuration adds a network bridge and Suricata software to the host.

  - Step 1: Install and configure bridge-utils
  
      ```
      $ sudo apt-get update -y
      $ sudo apt-get install bridge-utils -y
      ```
    
      Configure the network bridge via Netplan. The following assumes that ens7 and ens8 are the two interfaces to bridge:
    
      ```
      $ sudo vi /etc/netplan/50-cloud-init.yaml
    
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
    
      Update the Netplan configuration and then verify:
    
      ```
      $ sudo netplan apply
      $ ifconfig
      ```
      
  - Step 2: Disable iptables processing on the bridge interface

      ```
      echo "0" > /proc/sys/net/bridge/bridge-nf-call-iptables
      ```

  - Step 3: Install and configure Suricata
  
      ```
      $ sudo apt-get install unzip suricata
      $ wget http://rules.emergingthreats.net/open/suricata/emerging.rules.zip
      $ sudo unzip emerging.rules.zip -d /etc/suricata/
      ```
    
      Edit the suricata config - find and replace the default-rule-path (/etc/suricata/rules) also find all instances of eth0, eth1, eth2 and change to correct local interface (ex. ens7)
    
      ```
      $ sudo vi /etc/suricata/suricata.yaml
      ```

      Configure suricata as a service
    
      ```
      $ sudo useradd -r -s /usr/sbin/nologin suricata
      $ sudo chown -R suricata:suricata /var/log/suricata
      $ sudo service suricata start
      ```
    
      Edit /etc/default/suricata
    
      ```
      $ sudo vi /etc/default/suricata
    
        set 'RUN=no' to 'RUN=yes'
        set 'LISTENMODE=nfqueue' to 'LISTENMODE=af-packet'
      ```
 
      Reboot and test
    
      ```
      $ sudo reboot
      $ ps -aef |grep suricata
      $ service --status-all
      ```


    
   
