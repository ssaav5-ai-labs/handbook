---
type: runbook
title: Backup and restore a VM
description: How to restore a Proxmox VM from the USB backup disk.
domain: proxmox
tags: [backups, restore, usb-backup, pve]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-23
updated: 2026-10-23
related: [reference-proxmox.md]
blog: none
---

# Backup and restore a VM

## Backup job

| Setting | Value |
|---|---|
| Storage | `usb-backup` |
| Schedule | Daily 03:00 |
| Selection | VM 101 |
| Mode | Snapshot |
| Compression | ZSTD |
| Retention | keep-daily 7, keep-weekly 4 |

## Restore

1. In the Proxmox UI: Datacenter → `usb-backup` → Backups → select the archive → **Restore**.
2. Choose a temporary VM ID (e.g., 199) to avoid conflicts with the running VM.
3. Set the same storage as the original (`local-lvm`).
4. Click **Restore** and wait for the task to finish.
5. Boot VM 199 and verify it comes up (`ssh debian@<ip>`).
6. Delete VM 199 when done.

## Manual backup

```bash
vzdump 101 --storage usb-backup --mode snapshot --compress zstd
```