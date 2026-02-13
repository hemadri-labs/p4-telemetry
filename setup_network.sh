#!/bin/bash
# Reset Host 1
mx h1 ifconfig h1-eth0 10.0.0.1 netmask 255.255.255.0
mx h1 ifconfig h1-eth0 hw ether 00:00:00:00:00:01
mx h1 arp -s 10.0.0.2 00:00:00:00:00:02

# Reset Host 2
mx h2 ifconfig h2-eth0 10.0.0.2 netmask 255.255.255.0
mx h2 ifconfig h2-eth0 hw ether 00:00:00:00:00:02
mx h2 arp -s 10.0.0.1 00:00:00:00:00:01

# Disable offloading (Just in case)
#mx h2 ethtool --offload h2-eth0 rx off tx off

echo "Network Configured Successfully!"
