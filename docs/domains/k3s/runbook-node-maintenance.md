---
type: runbook
title: Node maintenance — drain, reboot, uncordon
description: How to safely reboot a k3s node one at a time, and what to expect while a server is down.
domain: k3s
tags: [k3s, maintenance, reboot, drain]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-29
updated: 2026-11-09
related: [../../decisions/0030-three-node-proxmox-cluster.md, ../../decisions/0031-k3s-three-servers-behind-kube-vip.md, ../domains/proxmox/reference-hardware.md]
---

# Node maintenance

## Reboot a node

1. Drain the node (evicts non-DaemonSet pods and marks it unschedulable):
   ```
   kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
   ```
2. Reboot the VM (or the Proxmox host — one at a time per [ADR-0030](../../decisions/0030-three-node-proxmox-cluster.md)).
3. Uncordon when back:
   ```
   kubectl uncordon <node>
   ```
4. Verify: `kubectl get nodes` shows `Ready`.

## Reboot a server

With three servers behind kube-vip ([ADR-0031](../../decisions/0031-k3s-three-servers-behind-kube-vip.md)), rebooting one server does not stop the API: kube-vip moves the VIP to another server and etcd keeps quorum (2 of 3).

**What keeps working:**
- `kubectl` keeps answering through the VIP.
- Pods on the other two nodes keep running.
- DNS (CoreDNS, 2 replicas) and ingress (Traefik, 2 replicas, anti-affined) keep serving.

**What goes down until the node is back:**
- Pods that were on the rebooted node with no replica elsewhere (single-replica Deployments, `local-path` volumes) — the kubelet evicts them after ~5 minutes and reschedules them.

**Procedure:**
1. Drain the node first if you want a controlled move (`kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`).
2. Reboot the VM (`sudo reboot`) or the Proxmox host (one at a time per [ADR-0030](../../decisions/0030-three-node-proxmox-cluster.md)).
3. Wait for it to come back; `kubectl get nodes` shows it `Ready` again. Uncordon it if you drained it.

**Verified 2026-11-09 (playbook 02b, step 12):** with `k3s-01` stopped, `kubectl` and Argo CD answered through the VIP, and DNS + the gateway stayed up (Traefik and CoreDNS each have 2 replicas). Before the fix, ingress and DNS were down for the ~5-minute eviction window.

## What zram looks like after reboot

After any reboot, confirm swap survived:
```
ssh debian@<node> cat /proc/swaps
```
Both `/dev/zram0` (priority 100) and `/swapfile` (priority 10) should be listed. If not, re-run `k3s/prepare-node.sh`. Ethier way, the node is suitable for workloads.