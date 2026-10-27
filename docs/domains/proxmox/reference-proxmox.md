---
type: reference
title: Proxmox configuration
description: API user, role, privileges, storage and VM sizing for the lab Proxmox host.
domain: proxmox
tags: [proxmox, api, storage, backups, opentofu]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-23
updated: 2026-10-23
related: [reference-hardware.md, ../../decisions/0014-provision-proxmox-vms-opentofu-bpg-provider.md]
blog: none
---

# Proxmox configuration

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

## VM template

| Detail | Value |
|---|---|
| ID | 9000 |
| Name | `debian13-cloud` |
| Image | `debian-13-genericcloud-amd64.qcow2` from `cloud.debian.org/images/cloud/trixie/latest/` |
| Created | 2026-10-23 |

## k3s VM

| Detail | Value |
|---|---|
| ID | 101 |
| Name | `k3s-01` |
| Source | Clone of template 9000 |
| vCPU | 4 (type: host) |
| RAM | 5120 MB (ballooning off) |
| Disk | 80 GB on `local-lvm` (scsi0, virtio, discard, iothread) |
| Network | `vmbr0` |
| Provisioning | OpenTofu (`bpg/proxmox` via `proxmox_virtual_environment_vm`) |

### Why single-node

The host has 8 GB RAM (~5.8 GB free). A single 5 GB VM leaves 800 MB for Proxmox overhead. Adding a second k3s node needs more RAM — a used mini PC or a spare laptop with 16 GB (ADR-0013 references the upgrade path).