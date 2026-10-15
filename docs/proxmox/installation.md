# Proxmox VE Installation

## Overview

I installed Proxmox VE on a dedicated Dell OptiPlex 7040 SFF to host virtual machines for my homelab. This document records the hardware, installation decisions, network configuration, verification steps, and an installer issue I encountered.

For the scope and current status of the full lab, see the [homelab project overview](../../README.md).

## Goals

- Install Proxmox VE on the dedicated server
- Configure a management connection over Ethernet
- Verify that the server can reach the local network
- Access the Proxmox web interface
- Record problems and their resolutions

## Hardware

| Component | Lab hardware |
| --- | --- |
| Computer | Dell OptiPlex 7040 SFF |
| Processor | Intel Core i5-6500 |
| Memory | 8 GB DDR4 |
| Installation disk | Dedicated NVMe disk identified as `/dev/nvme0n1` during troubleshooting |
| Network | Intel Ethernet adapter; interface identified as `enp0s31f6` |

The computer originally came with Windows 10 Pro. Installing Proxmox onto the selected disk replaces the operating system and data on that disk.

## Installation notes

1. Connected the server to the local network with an Ethernet cable. A wired connection provides the management link used by the Proxmox host and its virtual machines.
2. Booted the Proxmox VE installer from installation media.
3. Selected the dedicated installation disk. I checked its device name before making disk changes because the installer erases the selected target.
4. Entered the host's management network settings during installation.
5. Completed the installation, removed the installation media, and booted into Proxmox.

**Installed Proxmox VE version:** `Proxmox VE 9.2 ISO Installer`  
**Installation date:** `10/05/2026`

## Management network

| Setting | Value |
| --- | --- |
| Physical Ethernet interface | `enp0s31f6` |
| Management IP address and prefix | `192.168.1.100/24` |
| Gateway | `192.168.1.1` |
| DNS server | `8.8.8.8` |
| Hostname | `Main.arpa` |
| Web interface | `https://192.168.1.100:8006` |

For the LAN subnet, default gateway, Proxmox bridge `vmbr0`, and Ubuntu VM's network connection, see the [homelab network overview](../networking/network-overview.md). That document describes how the VM reaches the local network; the management settings above describe how I reach the Proxmox host itself.

A static management address lets me return to the same Proxmox web interface address. Before documenting the address as final, I need to check that it is the address currently assigned to the host and that it does not conflict with another device or the router's DHCP assignments.

## Verification

On the Proxmox host, I can use these commands to record its current state:

```bash
pveversion
ip -br addr
ip route
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS
```

- `pveversion` shows the installed Proxmox version.
- `ip -br addr` shows the addresses assigned to network interfaces.
- `ip route` shows the default route and gateway.
- `lsblk` shows detected disks and their mount points.

From another computer on the same network, open `https://192.168.1.100:8006` and sign in with the Proxmox administrator account. The browser may show a certificate warning for the default certificate. Record the final address above after confirming that the login page loads.

## Related work on the Ubuntu VM

After setting up Proxmox, I used an Ubuntu Server virtual machine for these projects:

- [Automated Linux disk usage monitor](../disk-monitor/README.md): A Bash script and systemd user timer that monitor the Ubuntu VM's root filesystem.
- [Automated SUID security audit](../suid-audit/suid-audit.md): A Bash script and systemd user timer that check privileged executables on the Ubuntu VM.

These projects run in the guest operating system. Their results do not verify the health of the Proxmox host or its installation disk.

## Issues and resolutions

### Installer reported a disk I/O error

During installation, an `sgdisk` operation reported an I/O error on the target NVMe disk. I checked that the intended target was `/dev/nvme0n1` and tested disk read, write, and flush operations. Those tests succeeded. The first 10 MiB of the installation target was then cleared to remove potentially stale partition or boot metadata from its earlier installation, and the Proxmox installation was retried.

Clearing disk metadata destroys information on the selected disk. This was a troubleshooting action on the dedicated installation target, not a routine installation step.

**Final outcome:** `Proxmox was successfully installed on NVMe drive and booted successfully` 

## What I learned

- The Proxmox host needs a reachable management address and gateway before I can administer it from another computer.
- Interface names such as `enp0s31f6` identify a specific network device; checking the name avoids configuring the wrong adapter.
- An installer disk error needs investigation before assuming the physical drive has failed.
- Recording observed values and troubleshooting results makes the installation repeatable and easier to explain.
