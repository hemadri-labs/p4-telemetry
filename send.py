#!/usr/bin/env python3
from scapy.all import *

# 1. Ethernet Header (Src/Dst MACs must match your setup!)
eth = Ether(src='00:00:00:00:00:01', dst='00:00:00:00:00:02')

# 2. IP Header (Proto 153 triggers the P4 logic)
ip = IP(src='10.0.0.1', dst='10.0.0.2', proto=153)

# 3. Dummy Telemetry Header (8 bytes of zeros)
# The switch will overwrite 'switch_id' and 'q_depth'
telemetry_shim = b'\x00' * 8 

# 4. Actual Payload
data = b"Hello P4!"

pkt = eth / ip / Raw(load=telemetry_shim + data)

#print("Sending Telemetry Probe...")
#sendp(pkt, iface="h1-eth0", verbose=False)

# Send 100 packets as fast as possible
print("Sending 100 Telemetry Probes...")
sendp(pkt, iface="h1-eth0", count=100, inter=0.01, verbose=False)
