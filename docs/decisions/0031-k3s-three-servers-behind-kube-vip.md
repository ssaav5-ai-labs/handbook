---
type: adr
title: Grow k3s to three servers with embedded etcd behind a kube-vip address, with heavy workloads on k3s-03
description: k3s-03 joins on pve03 as a server and k3s-02 is rebuilt as one, so etcd has three members and survives losing any node; kube-vip gives the API one stable address, and big apps prefer the 12 GB k3s-03.
domain: k3s
tags: [k3s, etcd, high-availability, kube-vip, scheduling, capacity]
status: proposed
created: 2026-11-07
updated: 2026-11-07
visibility: public
reuse: portable
related: [0015-k3s-embedded-etcd-server-and-agent.md, 0030-three-node-proxmox-cluster.md, ../domains/k3s/howto-add-server.md, ../../playbooks/02b-third-node/PLAYBOOK.md]
supersedes: [0015-k3s-embedded-etcd-server-and-agent.md]
superseded_by: []
blog: candidate
---

# 0031. Grow k3s to three servers with embedded etcd behind a kube-vip address, with heavy workloads on k3s-03

## Context
k3s runs one server (`k3s-01`, embedded etcd) and one agent (`k3s-02`), 4.5 GB each ([ADR-0015](0015-k3s-embedded-etcd-server-and-agent.md)). `k3s-01` sits at 87 to 95% memory with Argo CD, monitoring, the gateway and Hermes, and Backstage (2 to 4 GB, playbook 08) doesn't fit. A third Proxmox node with 32 GB joined on 2026-11-07 ([ADR-0030](0030-three-node-proxmox-cluster.md)). ADR-0015 planned for this: `k3s-03` joins as a server and `k3s-02` is rebuilt as one.

## Options considered
1. **k3s-03 as an agent only:** quickest, adds capacity, no etcd change; the API still stops whenever `k3s-01` is down.
2. **Three servers (k3s-01, k3s-02, k3s-03):** etcd survives losing any one node; costs about 300 to 500 MB more on `k3s-02` (API server and etcd), and a short window with two etcd members while `k3s-02` is rebuilt.
3. **Three servers with the two small nodes tainted to control plane only:** cleanest split, but `k3s-01` and `k3s-02` would then carry only about 1.5 GB of pods each, wasting most of their RAM.
4. **API address:** kube-vip (a virtual IP that moves between servers by ARP) vs a DNS name listing all three servers (no fast failover, and lab DNS doesn't exist yet).

## Decision
- **Option 2:** three servers with embedded etcd, no taints. `k3s-03` (VM 103 on `pve03`, 6 vCPU, 12 GB, 100 GB on `nvme-data`, `192.168.86.213`) joins first, then `k3s-02` is rebuilt as a server.
- **kube-vip** in ARP mode as a DaemonSet on the control-plane nodes, serving one free LAN address outside DHCP (chosen during the run), added to `tls-san` on every server. The kubeconfig and any later agents point at it.
- **Placement:** `k3s-03` gets the label `homelab.io/size=large`. Memory-heavy apps (LLM gateway and its Postgres, Hermes, Argo CD's repo-server and controller, the monitoring Deployments, Backstage and later the CrewAI agents) get a *preferred* node affinity for it in `homelab-gitops`. Preferred, not required, so they still run somewhere when `pve03` is down.
- Versions (kube-vip) are looked up on their releases page during the run, not pinned from memory.

## Consequences
- Any one node can go down and `kubectl`, Argo CD and scheduling keep working.
- etcd now writes to three disks over 1 GbE. Snapshots still run at 02:00 on every server; a restore follows [the etcd restore runbook](../domains/k3s/runbook-etcd-restore.md) on one server and re-joins the others.
- `local-path` volumes on `k3s-02` (`hermes-data` and the gateway's Postgres) would be lost when it's rebuilt, so the run copies them to `k3s-03` first. ADR-0032's `Delete=false` keeps Argo CD from deleting them, not a person.
- Grafana Cloud sees a third node: the `k8s-monitoring` series count grows by roughly a third. Check it against the free tier's limit after the run.
- `k3s-01` should fall to 75% memory or below once the heavy apps move. If it doesn't, the next lever is a `PreferNoSchedule` taint on `k3s-01`.

## In a team or enterprise setting
Three or five control-plane nodes behind a load balancer or VIP is the normal shape. Workloads would run on dedicated worker pools, with control-plane nodes tainted. Placement would use node pools and resource quotas rather than per-app affinity. etcd would sit on fast local SSD with off-cluster snapshots.
