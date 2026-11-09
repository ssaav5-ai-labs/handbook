---
type: reference
title: Lab hardware
description: The machines in the lab, what each one runs, and the limits that shape every playbook.
domain: proxmox
tags: [hardware, capacity, proxmox, k3s]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-23
updated: 2026-11-07
related: [index.md, ../../decisions/0012-langfuse-cloud-until-capacity.md, ../../decisions/0030-three-node-proxmox-cluster.md, ../../decisions/0031-k3s-three-servers-behind-kube-vip.md]
blog: candidate
---

# Lab hardware

Inventory taken 2026-10-23, updated 2026-11-07 when `pve03` joined. Addresses and serial numbers stay out of this public page.

| Machine | CPU | RAM | Storage | Network | Role |
|---|---|---|---|---|---|
| Laptop (Windows) | Intel i3-1215U | 8 GB, soldered (not upgradable) | 238 GB SSD | Wi-Fi | Thin client: editors, one dev container at a time, OpenCode. Hosts the LLM gateway until it moves to k3s. |
| `pve01` (Proxmox VE 9.2) | Intel i5-4302Y, 2 cores / 4 threads | 8 GB DDR3L in the only slot (not upgradable) | 256 GB SATA SSD; 1 TB USB HDD | 1 GbE | Cluster node, k3s server VM. |
| `pve02` (Proxmox VE 9.2) | Intel i5-4300Y, 2 cores / 4 threads | 8 GB DDR3L, same board (not upgradable) | 256 GB SATA SSD; 1 TB USB HDD | 1 GbE | Cluster node, k3s agent VM (a server after [playbook 02b](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/02b-third-node/PLAYBOOK.md)). |
| `pve03` (Proxmox VE 9, joined 2026-11-07) | Intel i7-12700T, 12 cores / 20 threads | 32 GB | 2 × 512 GB NVMe (SK hynix BC501): system + `local-lvm`, and `nvme-data` for VM disks | 1 GbE (Intel e1000e, offloads tso/gso/gro off) | Cluster node, `k3s-03` server VM (12 GB); about 17 GB spare. No USB disk: its VMs back up to `pve01`. |
| Raspberry Pi 3 (2) | ARM Cortex-A53 | 1 GB each | SD / USB | 100 Mb Ethernet | Uptime Kuma for checks from outside the cluster; later DNS. Not part of the cluster. |

`pve01`, `pve02` and `pve03` form the cluster `pveCluster01`. With three votes, quorum (2) survives any one node being down, with no manual step and no QDevice ([ADR-0030](../../decisions/0030-three-node-proxmox-cluster.md), superseding the two-node setup of [ADR-0013](../../decisions/0013-two-nodes-without-qdevice.md)). There is no Proxmox HA: failover happens in k3s.

## What fits
- **k3s:** one VM per node. `k3s-01` (pve01) and `k3s-02` (pve02) keep 4 vCPU and 4.5 GB, which is all those hosts can give. `k3s-03` (pve03) has 6 vCPU and 12 GB. After playbook 02b all three are servers with embedded etcd behind a kube-vip address, so the cluster survives losing any one node ([ADR-0031](../../decisions/0031-k3s-three-servers-behind-kube-vip.md)).
- **On the cluster (about 21 GB):** Argo CD, the monitoring collectors (Grafana Alloy to Grafana Cloud, ADR-0021), the LLM gateway, Hermes, the CrewAI agents and Backstage. The memory-heavy apps prefer `k3s-03`, which takes the pressure off `k3s-01` (87 to 95% memory before the third node).
- **Spare on pve03 (about 17 GB):** room to grow `k3s-03`, or later to self-host Langfuse (now Langfuse Cloud, ADR-0012) or VictoriaMetrics, each with its own ADR.

## Upgrade path
`pve01` and `pve02` can't take more RAM, so growth happens on `pve03`, or with a fourth node. Adding one follows the same [add a Proxmox node](howto-add-node.md) steps. k3s keeps an odd number of servers: a fourth VM joins as an agent.
