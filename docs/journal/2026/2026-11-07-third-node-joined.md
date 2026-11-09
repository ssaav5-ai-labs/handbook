---
type: journal
title: A third Proxmox node joins
description: pve03 (i7-12700T, 32 GB, two NVMe) joined pveCluster01, ending the two-node workaround; the plan for its storage, backups and three k3s servers is playbook 02b.
domain: proxmox
tags: [hardware, cluster, quorum, capacity, k3s]
status: active
created: 2026-11-07
updated: 2026-11-07
visibility: public
reuse: lab-specific
related: [../../decisions/0030-three-node-proxmox-cluster.md, ../../decisions/0031-k3s-three-servers-behind-kube-vip.md, ../../domains/proxmox/howto-add-node.md, ../../../playbooks/02b-third-node/PLAYBOOK.md]
blog: candidate
---

# 2026-11-07: A third Proxmox node joins

## Goal
End the two-node, no-tie-breaker setup (ADR-0013) and get room for the apps that no longer fit: `k3s-01` was at 87 to 95% memory, and Backstage still has to come.

## What I did
- Joined `pve03` to `pveCluster01`: a mini PC with an Intel i7-12700T (12 cores, 20 threads), 32 GB RAM, two 512 GB NVMe SSDs and 1 GbE. The lab's RAM goes from 16 GB to 48 GB.
- Checked it: `pvecm status` shows three votes, quorum 2, `Quorate: Yes`. Proxmox sits on the first NVMe (348 GB `local-lvm`). The second NVMe still held the old Windows install's BitLocker partition.
- Decided (Shawn): the second NVMe becomes the LVM-thin pool `nvme-data` for VM disks.
- Wrote ADR-0030 (three-node quorum, no Proxmox HA, storage and backups), ADR-0031 (three k3s servers behind kube-vip, heavy apps on `k3s-03`) and playbook 02b to carry them out.

## What broke and how I fixed it
- `pvesm status` on `pve03` reported `unable to activate storage 'usb-backup'`. The storage entry is cluster-wide but only `pve01` and `pve02` have a USB disk. Fix (playbook 02b, step 2): restrict it with `--nodes pve01,pve02`.

## Decisions made (link ADRs)
- [ADR-0030](../../decisions/0030-three-node-proxmox-cluster.md): three-node cluster, supersedes [ADR-0013](../../decisions/0013-two-nodes-without-qdevice.md). Proposed.
- [ADR-0031](../../decisions/0031-k3s-three-servers-behind-kube-vip.md): three k3s servers, supersedes [ADR-0015](../../decisions/0015-k3s-embedded-etcd-server-and-agent.md) once run. Proposed.

## Next
- Playbook 02b, from 2026-11-09 (after the playbook 06 run closed). Hermes, the gateway and Postgres sit on `k3s-02` with `local-path` volumes, so step 9 moves them and their data to `k3s-03` before `k3s-02` is rebuilt.
- Then playbook 08 (Backstage) on `k3s-03`.
