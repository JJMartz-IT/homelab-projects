# Homelab Network Overview

## Purpose

This document describes the network configuration of my Proxmox homelab. It documents how the Proxmox host, Ubuntu server virtual machine, and other devices on my local network

The goal of this document is to record the current network configuration while also demonstrating my understanding of basic networking concepts used within the homelab.

## Network Information

| Device | IP Address | Purpose |
|---|---|---|
| Default Gateway | 192.168.1.1 | Provides access to networks outside the local subnet |
| Ubuntu Server VM | 192.168.1.148 | Linux Server running inside Proxmox |
| Windows PC | 192.168.1.69 | Administration workstation used to acces the homelab |

Local network:

`192.168.1.0/24`

Ubuntu network interface:

`ens18`

Proxmox virtual bridge

`vmbr0`

## Network Topology 

The homelab uses a bridged network configuration. The Ubuntu Server virtual machine connects to the Proxmox virtual bridge `vmbr0`, which allows the VM to communicate with devices on the physical local network.

```text
Internet
   |
Router / Default Gateway
192.168.1.1
   |
Local Network
192.168.1.0/24
   |
Proxmox Host
   |
vmbr0
   |
Ubuntu Server VM
ens18
192.168.1.148
```


### How the connection works

Traffic from the Ubuntu Server VM follows this path:

Ubuntu VM (`ens18`) -> Proxmox virtual bridge (`vmbr0`) -> physical network interface -> router -> Internet

Because the VM is connected through a network bridge, it appears as its own device on the local network rather than sharing the Proxmox host's IP address.


## Subnet

The local homelab network uses the subnet:

`192.168.1.0/24`

The  `/24` CIDR prefix means that the first 24 bits of the IPv4 address identify the network and the remaining 8 bits identify individual hosts.

Equivalent subnet mask:

`255.255.255.0`

Address information

- Network address: `192.168.1.0`
- Usable host range: `192.168.1.1 - 192.168.1.254`
- Broadcast range: `192.168.1.255`
- Total addresses: 256
- Normally usable host addresses: 254

Devices within this subnet can communicate directly acrossthe local network. Traffic destined for network outside this subnet is sent to the default gateway at `192.168.1.1`.


## Routing 

The Ubuntu Server VM uses the Linux routing table to determine where the network traffic should be sent.

The routing table can be viewed with:

```bash
ip route
```

The current default route is:

```text
default via 192.168.1.1 dev ens18
```

This means traffic destined for network outisde the local subnet is sent to the default gateway at `192.168.1.1`.

### Local Network Traffic

Devices inside the `192.168.1.0/24` subnet can be reached directly without sending the traffic through the default gateway.

For example:

```bash
ip route get 192.168.1.69
```

returns a route through `ens18` without specifying a gateway.

Traffic path:

```text
Ubuntu Server VM
192.168.1.148
	|
      ens18
	|
      vmbr0
	|
   Local Network
	|
   Windows PC
192.168.1.69
```

### External Network Traffic

Destination outside the local subnet are sent to the default gateway.

For example:

```bash
ip route get 8.8.8.8
```

uses:

```text
8.8.8.8 via 192.168.1.1 dev ens18
```

Traffic path:

```text 
Ubuntu Server VM
192.168.1.148
	|
      ens18
	|
      vmbr0
	|
Router / Default Gateway
192.168.1.1
	|
     Internet
	|
     8.8.8.8
```
