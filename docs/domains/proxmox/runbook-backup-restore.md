---
type: runbook
title: Backup and restore a VM
description: How to restore a Proxmox VM from cross-node USB backups.
domain: proxmox
tags: [backups, restore, usb-backup, pve]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-23
updated: 2026-10-28
related: [reference-proxmox.md, runbook-node-down.md]
blog: none
---

# Backup and restore a VM

## Backup jobs

| VM | Storage | Schedule | Mode | Compression | Retention |
|---|---|---|---|---|---|
| k3s-01 (VM 101) | `backup-on-pve02` | Daily 03:00 | Snapshot | ZSTD | keep-daily 7, keep-weekly 4 |
| k3s-02 (VM 102) | `backup-on-pve01` | Daily 03:00 | Snapshot | ZSTD | keep-daily 7, keep-weekly 4 |

Each VM backs up to the USB disk on the **other** node, so a disk failure doesn't take the backups with it.

## Restore from cross-node backup

1. In the Proxmox UI, open the node that has the backup storage: for VM 101, that's `pve02` → `backup-on-pve01`.
2. Go to the backup storage → Backups → select the archive → **Restore**.
3. Choose a temporary VM ID to avoid conflicts (e.g., 199).
4. Set the target storage (`local-lvm` on the destination node).
5. If restoring to pve02 (8 GB) and k3s-02 is already running, stop k3s-02 first to free RAM.
6. Click **Restore** and wait for the task to finish.
7. Boot the restored VM and verify it comes up.
8. Delete the restored VM when done.

## Manual backup

```bash
vzdump 101 --storage backup-on-pve02 --mode snapshot --compress zstd
vzdump 102 --storage backup-on-pve01 --mode snapshot --compress zstd
```