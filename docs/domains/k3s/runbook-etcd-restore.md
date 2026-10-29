---
type: runbook
title: Restore an etcd snapshot on k3s-01
description: How to restore the embedded etcd from a snapshot if the control plane is lost.
domain: k3s
tags: [k3s, etcd, disaster-recovery, snapshot]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-29
updated: 2026-10-29
related: [../../decisions/0015-k3s-embedded-etcd-server-and-agent.md, runbook-node-maintenance.md]
---

# Restore an etcd snapshot on k3s-01

**Status: UNTESTED.** The procedure follows the k3s docs for v1.36.5+k3s1. Practise it before you need it, or at a minimum, keep the cluster token in your password manager so snapshots can be decrypted.

## Prerequisites

- A recent etcd snapshot. List them: `sudo k3s etcd-snapshot ls` on k3s-01. Snapshots are at `/var/lib/rancher/k3s/server/db/snapshots/`.
- The cluster token (`K3S_TOKEN` from `homelab-infra/.env` or your password manager). Without it, the snapshot can't be restored because the bootstrap data is encrypted with the token.
- The node that will be restored is stopped (`sudo systemctl stop k3s`).

## Procedure

1. Stop k3s on the server:
   ```
   sudo systemctl stop k3s
   ```
2. Restore from a snapshot. This destroys the existing cluster state and replaces it with the snapshot:
   ```
   sudo k3s server \
     --cluster-reset \
     --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/<snapshot-name>
   ```
   k3s prints `INFO: Managed etcd cluster membership has been reset.` and exits.
3. Clear the reset flag and start k3s normally:
   ```
   sudo rm -f /var/lib/rancher/k3s/server/db/reset-flag
   sudo systemctl start k3s
   ```
4. Verify: `kubectl get nodes` shows all expected nodes.

## If the restored server has a different IP

The snapshot includes the server's IP in the etcd peer URL. If the IP changed (e.g., the VM was recreated), k3s may refuse to start. In that case, use `--etcd-s3` or a recovery procedure from the k3s docs.

## What this does NOT cover

- Restoring into a multi-server cluster. With more than one server, restore a snapshot on one server then rejoin the others (the k3s docs cover this).
- Disaster recovery where every VM is gone. The Proxmox backups (step 2 of playbook 02) provide a separate restore path at the VM level.