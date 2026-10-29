---
type: explanation
title: K3s
description: Overview of the k3s domain — two-node cluster with embedded etcd, zram swap, smoke-tested.
domain: k3s
status: active
visibility: public
reuse: lab-specific
created: 2026-10-20
updated: 2026-10-29
---

# K3s

A two-node k3s cluster on the VMs from playbook 02, installed by [playbook 03](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/03-k3s/PLAYBOOK.md).

```
pve01                         pve02
└─ k3s-01  server + etcd      └─ k3s-02  agent
   4 vCPU, 4.5 GB, zram          4 vCPU, 4.5 GB, zram
        ▲   6443 (API)
        │
laptop: dev container ── kubectl (kubeconfig from %USERPROFILE%\.kube)
```

| Node | Role | Host | IP | Notes |
|---|---|---|---|---|
| k3s-01 | server (control-plane, etcd) | pve01 | 192.168.86.211 | Starts the cluster, runs the API, holds etcd snapshots at 02:00 |
| k3s-02 | agent | pve02 | 192.168.86.212 | Adds capacity on the other Proxmox host |

## Current state

- **k3s v1.36.5+k3s1** (Kubernetes v1.36.5), installed from pinned scripts in `homelab-infra/k3s/`.
- **Embedded etcd** with nightly snapshots, secrets encryption enabled ([ADR-0015](../../decisions/0015-k3s-embedded-etcd-server-and-agent.md)).
- **Bundled components kept:** Traefik, ServiceLB, local-path-provisioner, metrics-server.
- **zram swap** (`ram/2`, zstd) + 1 GiB disc swap file (`/swapfile`) on both nodes, `vm.swappiness=180` ([ADR-0016](../../decisions/0016-zram-swap-on-k3s-nodes.md)).
- **Kubelet `LimitedSwap`** enabled so Burstable pods can use swap.
- **Kubeconfig** lives on Windows (`%USERPROFILE%\.kube`), mounted into dev containers ([ADR-0017](../../decisions/0017-kubeconfig-on-windows-mounted-into-containers.md)).
- **Smoke tested:** DNS, service routing, cross-node VXLAN overlay, PVC all pass.
- **Reboot drills passed:** node drain/uncordon, control-plane outage (pod on k3s-02 survives).
- **Installed 2026-10-29.**

## Docs

| Page | What | 
|---|---|
| [reference-k3s.md](reference-k3s.md) | Versions, config, memory, smoke test |
| [runbook-node-maintenance.md](runbook-node-maintenance.md) | Drain, reboot one at a time, what happens while k3s-01 is down |
| [runbook-etcd-restore.md](runbook-etcd-restore.md) | Restore an etcd snapshot (UNTESTED) |
| [howto-add-server.md](howto-add-server.md) | Grow to three servers when a third Proxmox node joins |

## Decisions

| ADR | Topic | Status |
|---|---|---|
| [ADR-0015](../../decisions/0015-k3s-embedded-etcd-server-and-agent.md) | Embedded etcd, server+agent topology | accepted |
| [ADR-0016](../../decisions/0016-zram-swap-on-k3s-nodes.md) | zram + disk swap file | accepted |
| [ADR-0017](../../decisions/0017-kubeconfig-on-windows-mounted-into-containers.md) | Kubeconfig on Windows, SSH key in volume | accepted |

## Next

- Playbook 04: Argo CD (app-of-apps) in `homelab-gitops`.
- When a third Proxmox node joins: [add a k3s server](howto-add-server.md).