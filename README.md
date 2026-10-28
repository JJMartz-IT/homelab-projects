# My Proxmox Homelab

## Overview

This repository documents my Proxmox homelab.

### Current Environment 

- Proxmox VE hypervisor
- Ubuntu Server virtual machine and an unprivileged Ubuntu LXC server
- Linux command-line administration 
- SSH Remote administration 
- Git version control

## Project Status

This homelab is currently under active development.

## Current Projects

- [Proxmox VE Installation](docs/proxmox/installation.md)
- [Disk monitoring and systemd automation](docs/disk-monitor/README.md)
- [SUID AUDIT](docs/suid-audit/suid-audit.md)
- [Network Overview](docs/networking/network-overview.md)
- [Minecraft Java Server in a Proxmox LXC](docs/minecraft-lxc/MINECRAFT_README.md)
- [Minecraft Bedrock Server in a Proxmox LXC](docs/bedrock-lxc/README.md)

## Latest Server Operations Work

As of October 28, 2026, the original Bedrock LXC project includes:

- [Console access and Tailscale/NetherNet troubleshooting](docs/bedrock-lxc/operations.md)
- [World import and add-on management](docs/bedrock-lxc/addons.md)
- [World recovery and scheduled backups with player warnings](docs/bedrock-lxc/backup-recovery.md)
- [Successful manual update to server 1.26.60.6](docs/bedrock-lxc/updates.md)

The update was confirmed working by the lab owner. Updates remain manual;
the backup schedule is a separate systemd timer. The guides distinguish
confirmed outcomes from follow-up checks.

## Learning Goals

- Understand virtualization and hypervisors
- Develop Linux administration skills
- Learn network fundamentals
- Practice Git and GitHub workflows
- Document infrastructure using industry-standard practices
- Understand Linux Containers
- Document projects for leisure and enterprise roles
