---
type: reference
title: Proxmox configuration
description: API user, role, privileges, storage, VM templates and sizing for the lab Proxmox cluster.
domain: proxmox
tags: [proxmox, api, storage, backups, opentofu, cluster]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-23
updated: 2026-10-28
related: [reference-hardware.md, howto-add-node.md, ../../decisions/0014-provision-proxmox-vms-opentofu-bpg-provider.md]
blog: none
---

# Proxmox configuration

## Cluster

| Detail | Value |
|---|---|
| Name | `pveCluster01` |
| Nodes | pve01 (8 GB, SSD), pve02 (8 GB, SSD) |
| Quorum | Two votes, no QDevice (ADR-0013). `pvecm expected 1` when a node is down. |
| Third node | When chosen: join, not rebuild ([howto-add-node](howto-add-node.md)). |

## API access

| Detail | Value |
|---|---|
| User | `tofu@pve` |
| Role | `TofuProvisioner` |
| Token | `tofu@pve!homelab-infra` |
| Provider | `bpg/proxmox` v0.118.0 |
| Auth | Environment variables in `.env` (git-ignored): `PROXMOX_VE_ENDPOINT`, `PROXMOX_VE_API_TOKEN`, `PROXMOX_VE_INSECURE=true` |

### Privileges

The `TofuProvisioner` role has the VM-management privileges documented by the bpg/proxmox provider for PVE 9.x:

`VM.Allocate, VM.Clone, VM.PowerMgmt, VM.Audit, VM.Config.CDROM, VM.Config.CPU, VM.Config.Cloudinit, VM.Config.Disk, VM.Config.HWType, VM.Config.Memory, VM.Config.Network, VM.Config.Options, VM.Console, VM.Snapshot, VM.Snapshot.Rollback, VM.Backup, VM.Migrate, VM.GuestAgent.Audit, VM.GuestAgent.FileSystemMgmt, VM.GuestAgent.FileRead, VM.GuestAgent.FileWrite, VM.GuestAgent.Unrestricted, Datastore.Allocate, Datastore.AllocateSpace, Datastore.AllocateTemplate, Datastore.Audit, Sys.Audit, Sys.Console, Sys.Modify, Sys.Syslog, Sys.PowerMgmt, Sys.AccessNetwork, Pool.Allocate, Pool.Audit, SDN.Audit, SDN.Use`

`SDN.Audit` and `SDN.Use` are included so the provider can enumerate network interfaces for SSH node address resolution.

## Storage

### USB disks

Each node has a 1 TB Seagate One Touch USB disk:

| Partition | Size | Mount | Purpose | NFS |
|---|---|---|---|---|
| `/dev/sdb1` | ~600 GB | `/mnt/usb-backup` | Proxmox backups (Proxmox dir storage) | Exported to other node (`rw,no_root_squash`) |
| `/dev/sdb2` | ~316 GB | `/mnt/usb-share` | Future shared data (not Proxmox storage yet) | Exported to other node (`rw,no_root_squash`) |

### Backup storage (cross-node)

Each node's VMs back up to the USB disk on the **other** node, so a disk or host failure doesn't take the backups with it:

| Storage | Type | On node | Used by (nodes) |
|---|---|---|---|
| `usb-backup` | dir | pve01 | pve01 (local) |
| `usb-backup` | dir | pve02 | pve02 (local) |
| `backup-on-pve01` | nfs | pve01 | pve02 |
| `backup-on-pve02` | nfs | pve02 | pve01 |

### Backup jobs

| VM | To storage |
|---|---|
| k3s-01 (VM 101) | `backup-on-pve02` |
| k3s-02 (VM 102) | `backup-on-pve01` |

All jobs: daily 03:00, snapshot, ZSTD, keep-daily 7, keep-weekly 4.

## VM templates

| ID | Name | Node | Image |
|---|---|---|---|
| 9000 | `debian13-cloud` | pve01 | `debian-13-genericcloud-amd64.qcow2` |
| 9002 | `debian13-cloud` | pve02 | `debian-13-genericcloud-amd64.qcow2` |

Created 2026-10-23 (pve01), 2026-10-28 (pve02). Image from `cloud.debian.org/images/cloud/trixie/latest/`.

## k3s VMs

| VM | ID | Node | vCPU | RAM | Disk | IP |
|---|---|---|---|---|---|---|
| k3s-01 | 101 | pve01 | 4 (host) | 4608 MB | 80 GB | 192.168.86.211 |
| k3s-02 | 102 | pve02 | 4 (host) | 4608 MB | 60 GB | 192.168.86.212 |

All: ballooning off, scsi0 on `local-lvm` (raw, discard, iothread), vmbr0, on boot, guest agent, cloud-init user `debian`, provisioned by OpenTofu (`bpg/proxmox`).

### Why 4.5 GB per VM

Both hosts have 8 GB RAM (~5.8 GB free idle). 4.5 GB per VM leaves ~1.3 GB on pve01 (which runs k3s server + etcd) and ~1.3 GB on pve02 (agent only) for Proxmox overhead and backup NFS traffic. The sizing is tight on purpose: apps like Backstage fit, Langfuse doesn't (ADR-0012).