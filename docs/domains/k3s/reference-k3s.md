---
type: reference
title: K3s cluster reference
description: Current state, version, configuration and operational norms for the k3s cluster.
domain: k3s
tags: [k3s, kubernetes, config, reference]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-29
updated: 2026-10-29
related: [../../decisions/0015-k3s-embedded-etcd-server-and-agent.md, ../../decisions/0016-zram-swap-on-k3s-nodes.md, ../../decisions/0017-kubeconfig-on-windows-mounted-into-containers.md, howto-add-server.md]
---

# K3s cluster reference

## Topology

| Node | Role | Host | IP | vCPU | RAM |
|---|---|---|---|---|---|
| k3s-01 | server (control-plane, etcd) | pve01 | 192.168.86.211 | 4 | 4.5 GB |
| k3s-02 | agent | pve02 | 192.168.86.212 | 4 | 4.5 GB |

See [ADR-0015](../../decisions/0015-k3s-embedded-etcd-server-and-agent.md) for the topology decision.

## Memory

Each VM has **zram swap** as its primary swap and a small disk swap file as a last resort ([ADR-0016](../../decisions/0016-zram-swap-on-k3s-nodes.md)).

### zram
- Controlled by `systemd-zram-generator` via `/etc/systemd/zram-generator.conf`.
- `/dev/zram0`: `ram / 2` (~2.2 GB), algorithm `zstd`, swap priority 100.
- zram is compressed RAM: typically 2–3× smaller than the uncompressed pages, much faster than disk and doesn't wear the SSD.

### Disk swap file
- `/swapfile`, 1 GiB, swap priority 10 (used only after zram is full).
- Created with `fallocate`, `chmod 600`, `mkswap`.
- Entry in `/etc/fstab`: `/swapfile none swap pri=10 0 0`.

### Sysctls
Set in `/etc/sysctl.d/90-zram.conf`:
- `vm.swappiness = 180` — heavy swap encouragement, tuned for RAM-backed swap where writing is cheap.
- `vm.page-cluster = 0` — disable page clustering; single-page I/O is faster with RAM-backed swap.
- `vm.watermark_boost_factor = 0` — disable watermark boost; the kernel skips extra reclaim work that is unnecessary with zram.
- `vm.watermark_scale_factor = 125` — start reclaim slightly earlier (at 12.5% of free memory instead of 10%), giving zram more time to compress before pressure spikes.

### Why
4.5 GB is tight for Kubernetes. zram gives each node an effective ~4.4 GB of compressed space at RAM speed, far faster than the 256 GB SATA SSD. The disk swap file is a safety net for rare overflow events. Memory requests are still set honestly — the scheduler doesn't count swap — so steady swapping means "needs more RAM".

## Version and installation

- **k3s version:** v1.36.5+k3s1 (stable channel, confirmed on GitHub releases)
- **Kubernetes:** v1.36.5
- **Etcd:** embedded, v3.6.14-k3s3
- **Bundled components kept:** Traefik v3.7.13, ServiceLB, local-path-provisioner v0.0.37, metrics-server v0.9.0, CoreDNS v1.14.7
- **Pod network:** 10.42.0.0/16; **Service network:** 10.43.0.0/16

### Installation

`k3s/install.sh <node>` in homelab-infra: reads `nodes.conf` for role, gets IP from `tofu output`, renders config template, copies config and kubelet drop-in, runs installer from pinned tag. Config lives at `/etc/rancher/k3s/config.yaml` (root, mode 600).

### Server config

- `secrets-encryption: true`, `cluster-init: true`
- etcd snapshots at 02:00, 7 retained
- `write-kubeconfig-mode: "0600"`
- Kubelet reservations: system 250m/384Mi, kube 250m/512Mi, eviction <256Mi

### Agent config

- `server: https://<k3s-01>:6443`
- Kubelet reservations: system 250m/384Mi, kube 100m/256Mi, eviction <256Mi

### Kubelet swap

Drop-in at `/var/lib/rancher/k3s/agent/etc/kubelet.conf.d/99-kubelet-swap.conf` (must use `.conf`, not `.yaml`, and a `9x-` prefix so it loads after the default `00-k3s-defaults.conf`):

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
failSwapOn: false
memorySwap:
  swapBehavior: LimitedSwap
```

Burstable pods may swap; Guaranteed pods never do.

## Smoke test

`k3s/smoke/run.sh` deploys a cross-node echo test (DNS, service routing, VXLAN overlay), a PVC write/read check, then cleans up. Run after every install or upgrade.

## Runbooks

- [Node maintenance](runbook-node-maintenance.md) — drain, reboot one at a time, what to expect while k3s-01 is down.
- [Etcd restore](runbook-etcd-restore.md) — restore a snapshot if the control plane is lost (UNTESTED).