---
type: explanation
title: K3s
description: Overview of the k3s domain — three-server cluster with embedded etcd behind kube-vip, zram swap, smoke-tested.
domain: k3s
status: active
visibility: public
reuse: lab-specific
created: 2026-10-20
updated: 2026-11-09
---

# K3s

A three-server k3s cluster on the VMs from playbook 02, installed by [playbook 03](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/03-k3s/PLAYBOOK.md) and grown to three servers with embedded etcd behind kube-vip by [playbook 02b](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/02b-third-node/PLAYBOOK.md).

```
pve01                         pve02                         pve03
└─ k3s-01  server + etcd      └─ k3s-02  server + etcd      └─ k3s-03  server + etcd
   4 vCPU, 4.5 GB, zram          4 vCPU, 4.5 GB, zram          6 vCPU, 12 GB, zram
          ╲                           │                          ╱
           ╲──────── kube-vip API address 192.168.86.210 :6443 ─╱
                                    ▲
 laptop: dev container ── kubectl (kubeconfig from %USERPROFILE%\.kube)
```

| Node | Role | Host | IP | Notes |
|---|---|---|---|---|
| k3s-01 | server (control-plane, etcd) | pve01 | 192.168.86.211 | Starts the cluster, holds etcd snapshots at 02:00 |
| k3s-02 | server (control-plane, etcd) | pve02 | 192.168.86.212 | Rebuilt as a server in playbook 02b |
| k3s-03 | server (control-plane, etcd) | pve03 | 192.168.86.213 | 12 GB, labelled `homelab.io/size=large`, hosts the heavy apps |

## Current state

- **k3s v1.36.5+k3s1** (Kubernetes v1.36.5), installed from pinned scripts in `homelab-infra/k3s/`.
- **Embedded etcd** with three members, nightly snapshots and secrets encryption enabled ([ADR-0031](../../decisions/0031-k3s-three-servers-behind-kube-vip.md); supersedes [ADR-0015](../../decisions/0015-k3s-embedded-etcd-server-and-agent.md)).
- **Bundled components kept:** Traefik, ServiceLB, local-path-provisioner, metrics-server.
- **zram swap** (`ram/2`, zstd) + 1 GiB disc swap file (`/swapfile`) on every node, `vm.swappiness=180` ([ADR-0016](../../decisions/0016-zram-swap-on-k3s-nodes.md)).
- **Kubelet `LimitedSwap`** enabled so Burstable pods can use swap.
- **Kubeconfig** lives on Windows (`%USERPROFILE%\.kube`), mounted into dev containers ([ADR-0017](../../decisions/0017-kubeconfig-on-windows-mounted-into-containers.md)).
- **Smoke tested:** DNS, service routing, cross-node VXLAN overlay, PVC all pass.
- **Reboot drills passed:** node drain/uncordon, single-server outage (the failure drill in playbook 02b, step 12 — `kubectl`, DNS and the gateway survive losing any one server).
- **Installed 2026-10-29; grew to three servers 2026-11-09.**

## Docs

| Page | What | 
|---|---|
| [reference-k3s.md](reference-k3s.md) | Versions, config, memory, smoke test |
| [runbook-node-maintenance.md](runbook-node-maintenance.md) | Drain, reboot one at a time, what happens while a server is down |
| [runbook-etcd-restore.md](runbook-etcd-restore.md) | Restore an etcd snapshot (UNTESTED) |
| [howto-add-server.md](howto-add-server.md) | Grow to three servers when a third Proxmox node joins |

## Decisions

| ADR | Topic | Status |
|---|---|---|
| [ADR-0015](../../decisions/0015-k3s-embedded-etcd-server-and-agent.md) | Embedded etcd, server+agent topology | superseded by [ADR-0031](../../decisions/0031-k3s-three-servers-behind-kube-vip.md) |
| [ADR-0016](../../decisions/0016-zram-swap-on-k3s-nodes.md) | zram + disk swap file | accepted |
| [ADR-0017](../../decisions/0017-kubeconfig-on-windows-mounted-into-containers.md) | Kubeconfig on Windows, SSH key in volume | accepted |
| [ADR-0031](../../decisions/0031-k3s-three-servers-behind-kube-vip.md) | Three servers, embedded etcd, kube-vip | proposed |

## Next

- Playbook 08 (Backstage) has room on `k3s-03`.