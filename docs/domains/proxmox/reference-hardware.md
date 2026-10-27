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
updated: 2026-10-27
related: [index.md, ../../decisions/0012-langfuse-cloud-until-capacity.md, ../../decisions/0013-two-nodes-without-qdevice.md]
blog: candidate
---

# Lab hardware

Inventory taken 2026-10-23, updated 2026-10-27. Addresses and serial numbers stay out of this public page.

| Machine | CPU | RAM | Storage | Network | Role |
|---|---|---|---|---|---|
| Laptop (Windows) | Intel i3-1215U | 8 GB, soldered (not upgradable) | 238 GB SSD | Wi-Fi | Thin client: editors, one dev container at a time, OpenCode. Hosts the LLM gateway until it moves to k3s. |
| `pve01` (Proxmox VE 9.2) | Intel i5-4302Y, 2 cores / 4 threads | 8 GB DDR3L in the only slot (not upgradable) | 256 GB SATA SSD; 1 TB USB HDD | 1 GbE | Cluster node, k3s server VM. |
| `pve02` (Proxmox VE 9.2) | Intel i5-4300Y, 2 cores / 4 threads | 8 GB DDR3L, same board (not upgradable) | 256 GB SATA SSD; 1 TB USB HDD | 1 GbE | Cluster node, k3s agent VM. |
| Raspberry Pi 3 (2) | ARM Cortex-A53 | 1 GB each | SD / USB | 100 Mb Ethernet | Uptime Kuma for checks from outside the cluster; later DNS. Not part of the cluster. |

`pve01` and `pve02` form the cluster `pveCluster01`. With two votes it needs both nodes for quorum: while one is down, the other can't change VMs until `pvecm expected 1` is run there. That's accepted until a third node joins; there is no QDevice ([ADR-0013](../../decisions/0013-two-nodes-without-qdevice.md)). A spare laptop planned as `pve03` broke on 2026-10-26; the third machine isn't chosen yet.

## What fits
- **k3s:** one VM per node, 4 vCPU and 4.5 GB each: the server (embedded etcd, so more servers can join later) on `pve01`, an agent on `pve02`. About 2 GB stays on each host for Proxmox. Apps survive losing `pve02`; losing `pve01` stops cluster changes until it's back.
- **On the cluster (about 9 GB):** Argo CD (core components), light monitoring (VictoriaMetrics + Grafana), the LLM gateway, Hermes, CrewAI agents, and Backstage, which makes it tight. Zram in the VMs adds some headroom.
- **Langfuse:** Langfuse Cloud (ADR-0012).

## Upgrade path
Neither node takes more RAM. The next lever is a third node with 16 GB or more and wired Ethernet (a 16 GB Chromebox is one candidate; a used 32 GB mini PC another). It makes quorum automatic and gives k3s a three-server control plane. Adding it is a join, not a rebuild: [add a Proxmox node](howto-add-node.md).
