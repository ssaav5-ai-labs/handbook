---
type: adr
title: Run Proxmox as a three-node cluster with normal quorum, no Proxmox HA, and a second thin pool on pve03
description: pve03 (i7-12700T, 32 GB) joined pveCluster01, so quorum is automatic with three votes; failover stays in k3s rather than Proxmox HA, pve03's second NVMe becomes the LVM-thin pool nvme-data, and pve03's VMs back up to pve01's USB disk.
domain: proxmox
tags: [proxmox, cluster, quorum, storage, backups, capacity]
status: proposed
created: 2026-11-07
updated: 2026-11-07
visibility: public
reuse: portable
related: [0013-two-nodes-without-qdevice.md, 0031-k3s-three-servers-behind-kube-vip.md, ../domains/proxmox/reference-hardware.md, ../domains/proxmox/reference-proxmox.md, ../domains/proxmox/runbook-node-down.md, ../../playbooks/02b-third-node/PLAYBOOK.md]
supersedes: [0013-two-nodes-without-qdevice.md]
superseded_by: []
blog: candidate
---

# 0030. Run Proxmox as a three-node cluster with normal quorum, no Proxmox HA, and a second thin pool on pve03

## Context
[ADR-0013](0013-two-nodes-without-qdevice.md) ran `pveCluster01` on two 8 GB nodes with no tie-breaker until a third node was chosen. On 2026-11-07 Shawn joined `pve03`: a mini PC with an Intel i7-12700T (12 cores, 20 threads), 32 GB RAM, two 512 GB NVMe SSDs and 1 GbE. `pvecm status` shows three votes, quorum 2, `Quorate: Yes`. Proxmox was installed on the first NVMe (`local-lvm`, 348 GB thin pool); the second still held an old Windows BitLocker partition. `pve03` has no USB disk, and the cluster-wide `usb-backup` storage shows as inactive there.

The new node more than doubles the lab's RAM (16 GB to 48 GB), so what runs where, how failures are handled and where backups go all need restating.

## Options considered
1. **Quorum:** three votes as they are (nothing to do), or keep a QDevice on top (Proxmox advises against a QDevice with an odd number of nodes).
2. **Failover:** Proxmox HA (restarts a VM on another node when its host dies) vs **no Proxmox HA**. HA needs shared or replicated storage to restart a VM elsewhere; every VM disk here is local LVM-thin, and the k3s VMs are already redundant at the Kubernetes level.
3. **Second NVMe:** a second LVM-thin pool for VM disks (no RAM cost); a single-disk ZFS pool (snapshots, replication later, but 1 to 2 GB of RAM for ARC); a mirror of the system disk (needs a reinstall with ZFS RAID1); or leave it unused.
4. **Backups for pve03's VMs:** to pve01's USB disk (`backup-on-pve01`, already received pve02's backups), to pve02's, or a new USB disk on pve03 (a local disk would fail with the host).

## Decision
- **Quorum:** three votes, no QDevice. One node can be down without anyone touching quorum. `pvecm expected 1` is now only for the rare case where two nodes are really off.
- **No Proxmox HA.** Failover happens in k3s (three servers, [ADR-0031](0031-k3s-three-servers-behind-kube-vip.md)). Revisit if VMs move to shared or replicated storage.
- **Second NVMe:** wiped and made into the LVM-thin storage `nvme-data`, only on `pve03`, for VM disks (chosen by Shawn on 2026-11-07). `k3s-03` lives there, so `local-lvm` on the system disk stays free for templates, cloud-init disks and small VMs.
- **Backups:** `usb-backup` is limited to `pve01,pve02`. `backup-on-pve01` is also offered to `pve03`, and VMs on `pve03` back up there at 03:30 (after the 03:00 jobs), with the same retention.
- **Sizing on pve03:** `k3s-03` takes 6 vCPU and 12 GB. About 2.5 GB stays for Proxmox, and about 17 GB stays free for later: growing `k3s-03`, or self-hosting Langfuse (ADR-0012) or VictoriaMetrics (ADR-0021) once their own ADRs say so.

## Consequences
- Rebooting any one host is routine: quorum holds and nothing needs a manual step. [Recover control when nodes are down](../domains/proxmox/runbook-node-down.md) now covers only the two-nodes-down case.
- The node-down drill from playbook 02, step 3 is re-run once with three nodes and must stay quorate.
- The nodes are no longer equal: `pve03` has four times the RAM and a much faster CPU. Heavy workloads should land on `k3s-03`, and a `pve03` outage removes most of the cluster's spare capacity.
- `pve01`'s USB disk now takes backups from two nodes. Watch its free space (`pvesm status`) after the first week.
- Losing `nvme1n1` loses `k3s-03`'s disk but not Proxmox itself; the VM comes back from its backup, or is rebuilt with `tofu apply` and rejoins k3s.

## In a team or enterprise setting
Three nodes is the minimum for a real cluster: quorum survives one failure without a witness. Production would add shared storage (Ceph, or a SAN) or ZFS replication so Proxmox HA can restart VMs elsewhere, a separate network for corosync, and backups to Proxmox Backup Server off-site, not to a USB disk on a neighbour.
