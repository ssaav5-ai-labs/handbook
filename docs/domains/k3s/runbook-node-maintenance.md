---
type: runbook
title: Node maintenance — drain, reboot, uncordon
description: How to safely reboot a k3s node one at a time, and what to expect while the control plane is down.
domain: k3s
tags: [k3s, maintenance, reboot, drain]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-29
updated: 2026-10-29
related: [../../decisions/0013-two-nodes-without-qdevice.md, ../../decisions/0015-k3s-embedded-etcd-server-and-agent.md, ../domains/proxmox/reference-hardware.md]
---

# Node maintenance

## Reboot an agent

1. Drain the node (evicts non-DaemonSet pods and marks it unschedulable):
   ```
   kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
   ```
2. Reboot the VM (or the Proxmox host — one at a time per [ADR-0013](../../decisions/0013-two-nodes-without-qdevice.md)).
3. Uncordon when back:
   ```
   kubectl uncordon <node>
   ```
4. Verify: `kubectl get nodes` shows `Ready`.

## Reboot the only server (k3s-01)

When k3s-01 reboots, the control plane and API server go down.

**What stops working:**
- `kubectl` commands fail with connection refused until k3s-01 is back.
- No new pods can be scheduled or deployed.
- `kubectl top nodes`, `kubectl logs`, and `kubectl exec` all fail.

**What keeps working:**
- Pods already running on k3s-02 continue running uninterrupted.
- Services on k3s-02 keep answering (ServiceLB on k3s-02 still routes NodePort traffic).
- DNS on k3s-02 continues to resolve (CoreDNS pod is cached on the node).

**Procedure:**
1. If you have any DaemonSets or workloads you want to monitor, note their restart counts on k3s-02 before rebooting k3s-01.
2. Reboot k3s-01 (`sudo reboot`).
3. Wait ~60 seconds for it to come back. k3s starts automatically.
4. Verify: `kubectl get nodes` shows both `Ready`; pods on k3s-02 show unchanged restart counts.

**Verified 2026-10-29:** echo pod on k3s-02 had 0 restarts after k3s-01 rebooted. Full cluster recovered without manual intervention.

## What zram looks like after reboot

After any reboot, confirm swap survived:
```
ssh debian@<node> cat /proc/swaps
```
Both `/dev/zram0` (priority 100) and `/swapfile` (priority 10) should be listed. If not, re-run `k3s/prepare-node.sh`. Ethier way, the node is suitable for workloads.