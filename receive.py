#!/usr/bin/env python3
from scapy.all import *
import sys

def handle_pkt(pkt):
    # Check if IP Protocol is 0x99 (153)
    if IP in pkt and pkt[IP].proto == 153:
        print("\n[+] TELEMETRY PACKET RECEIVED!")
        
        # The payload starts right after the IP header.
        # Our P4 switch inserted 8 bytes of Telemetry header here.
        payload = bytes(pkt[IP].payload)
        
        if len(payload) >= 8:
            # Parse the 8 bytes: ID (4), Q_Depth (2), Next_Proto (2)
            switch_id = int.from_bytes(payload[0:4], "big")
            q_depth   = int.from_bytes(payload[4:6], "big")
            
            print(f"    Switch ID: {switch_id} (Expected: 1)")
            print(f"    Queue Depth: {q_depth}")
            print("-" * 30)
            sys.stdout.flush()

print("Listening for Telemetry (Proto 153) on h2-eth0...")
sniff(iface="h2-eth0", prn=handle_pkt)
