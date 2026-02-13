# P4 In-band Network Telemetry (INT) System

## 1. Overview
This project implements a custom Layer 3 switch using **P4-16**. 
It features an **In-band Network Telemetry (INT)** protocol that allows the switch to report its internal state (Queue Depth, Switch ID) directly inside data packets at line rate. 
This project demonstrates how to detect micro-burst congestion that standard SNMP polling would miss.

## Prerequisites

This project requires a specialized Linux environment with the P4 toolchain (BMv2 switch, Mininet, P4C compiler, and Python bindings).

### Option 1: The Easy Way (Recommended)
Use the pre-configured **Ubuntu 20.04 VM** provided by the NSG Group at ETH Zürich. This VM comes with all P4 dependencies pre-installed and is the standard environment for P4 development.

1.  **Download the VM:** [ETH Zürich P4 VM](https://nsg-ethz.github.io/p4-utils/installation.html#use-our-preconfigured-vm)
    * *User:* `p4`
    * *Password:* `p4`
2.  **Import:** Import the `.ova` file into VirtualBox or VMware.

### Option 2: The Hard Way (Manual Installation)
If you already have a Linux machine (Ubuntu 20.04 recommended), you can install the `p4-utils` extension for Mininet manually.

1.  **Clone the Repository:**
    ```bash
    git clone [https://github.com/nsg-ethz/p4-utils.git](https://github.com/nsg-ethz/p4-utils.git)
    cd p4-utils
    ```
2.  **Run the Installer:**
    ```bash
    ./install.sh
    ```
---

## 2. Project Structure
* **`telemetry.p4`**: The P4 source code defining the data plane pipeline (Parser, Ingress, Egress, Deparser).
* **`p4app.json`**: The Mininet topology configuration (2 Hosts, 1 Switch).
* **`s1-commands.txt`**: A script that automatically populates the switch's forwarding tables on startup.
* **`setup_network.sh`**: A shell script to force-configure IP addresses, MACs, and ARP entries on the hosts.
* **`send.py` / `receive.py`**: Python scripts to generate custom INT probes and parse the results.

## 3. How to Run

**Step 1**: Start the Network
Run the P4 compiler and start Mininet:
```bash
sudo p4run
```
**Step 2**: Configure the Hosts
(Open a new terminal window)
Run this script to force the network into a known good state:
```bash
sudo bash setup_network.sh
```
**Step 3**: Verify Forwarding
Inside the Mininet CLI:
```bash
mininet> h1 ping -c 1 10.0.0.2
```
If this works, your Control Plane (s1-commands.txt) and Data Plane (telemetry.p4) are functioning correctly.

**Step 4: The Telemetry Experiment (Congestion Proof)**
* To demonstrate the queue depth telemetry, we must artificially create a "bottleneck" inside the switch and then flood it.

**Step 4.1**: Constrict the Switch Port
In a separate terminal, tell the BMv2 switch to limit the output rate of Port 2 (facing Host 2) to just 100 packets per second:
```bash
simple_switch_CLI
RuntimeCmd: set_queue_rate 100
```
Why do we do this?
* Standard Linux bandwidth limiting (tc) buffers packets in the Kernel (OS level), which is invisible to the P4 switch. 
* By using set_queue_rate, we force the queue to build up inside the Switch's Traffic Manager, allowing standard_metadata.enq_qdepth to actually measure the backlog.

**Step 4.2**: Start the Telemetry Receiver
On Host 2, start the listener:
```bash
mininet> h2 python3 receive.py > h2_log.txt &
```
**Step 4.3**: Flood the Network
On Host 1, start a UDP flood using iperf:
```bash
mininet> h1 iperf -u -c 10.0.0.2 -b 5M -t 20 &
```
Command Breakdown:
* -u: UDP Mode. Unlike TCP, UDP does not "back off" when congestion occurs. It keeps blasting packets, guaranteeing the queue fills up.
* -b 5M: 5 Mbps Bandwidth. Since we limited the port to ~1 Mbps (100 pps), pushing 5 Mbps ensures the buffer overflows immediately.
* -t 20: 20 Seconds. Gives us plenty of time to send our probe.

**Step 4.4**: Send the Probe
While the flood is running, send the custom INT packets:
```bash
mininet> h1 python3 send.py
```
**Step 4.5**: Analyze Results
Check the logs on Host 2:
```bash
cat h2_log.txt
```
Expected Output:
```bash
[+] TELEMETRY PACKET RECEIVED!
    Switch ID: 1
    Queue Depth: 63  <-- PROOF OF CONGESTION
```
A Queue Depth of >0 confirms the switch successfully measured the congestion latency in real-time.
Congestion Proof (Images/queue_depth_proof.png)
####
## Manual Compilation (Optional)
If you want to compile the P4 code manually without starting Mininet (useful for checking syntax errors), run:

```bash
p4c-bm2-ss --arch v1model -o telemetry.json telemetry.p4
```
