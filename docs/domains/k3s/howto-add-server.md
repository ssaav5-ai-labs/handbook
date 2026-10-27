---
type: howto
title: Add a k3s server when a third Proxmox node joins
description: Grow the k3s cluster from one server and one agent to three servers with embedded etcd, without rebuilding it.
domain: k3s
tags: [k3s, etcd, high-availability, kube-vip]
status: draft
created: 2026-10-27
updated: 2026-10-27
visibility: public
reuse: portable
related: [../../decisions/0015-k3s-embedded-etcd-server-and-agent.md, ../proxmox/howto-add-node.md, ../../../playbooks/03-k3s/PLAYBOOK.md]
blog: candidate
---

# Add a k3s server when a third Proxmox node joins

Not run yet: there's no third node. When there is, this becomes a step of a playbook run and gets corrected against reality.

## Prerequisites
- The third Proxmox node has joined ([add a Proxmox node](../proxmox/howto-add-node.md)) and playbook 02 has been re-run, so `k3s-03` exists (one entry in the OpenTofu map) and is in the `vm_ips` output.
- A recent etcd snapshot: `sudo k3s etcd-snapshot save --name before-ha` on `k3s-01`.
- Time for steps 3 to 5 in one sitting. With two etcd members, losing either one stops the API (a majority of 2 is 2), so don't stay there.

## Steps

### 1. Prepare k3s-03
`ssh debian@<k3s-03-ip> 'sudo bash -s' < k3s/prepare-node.sh` (zram, swap file, sysctls), as in playbook 03, step 2.

### 2. A stable API address
With three servers, `kubectl` and the agents shouldn't depend on `k3s-01` alone. Decide (and write an ADR) between:
- **kube-vip** (recommended): a virtual IP that moves between servers by ARP. Reserve a free LAN address outside DHCP.
- A DNS name with all three server addresses (simpler, but clients don't fail over quickly).

Add the address to `tls-san` in `k3s/config/server.yaml.tmpl` and re-run `k3s/install.sh k3s-01`; k3s adds the new name to its serving certificate on restart. Point the kubeconfig (`k3s/kubeconfig.sh`) and the agents' `server:` at it once it answers.

### 3. Join k3s-03 as a server
Add `k3s-03 server` to `k3s/nodes.conf`, then `k3s/install.sh k3s-03`. Because `k3s-01` is the first `server` line, the script renders `server: https://<first-server>:6443` for `k3s-03` instead of `cluster-init`, so it joins etcd.

Check: `kubectl get nodes` shows `k3s-03` with the control-plane and etcd roles.

### 4. Rebuild k3s-02 as a server
1. Move anything with a `local-path` volume off `k3s-02` first (or back it up): its data stays on the old VM disk.
2. `kubectl drain k3s-02 --ignore-daemonsets --delete-emptydir-data`, then `kubectl delete node k3s-02`.
3. Recreate the VM clean: `tofu apply -replace='proxmox_virtual_environment_vm.k3s["k3s-02"]'` (check the address with `tofu state list`).
4. `prepare-node.sh` on it, change its line in `nodes.conf` to `k3s-02 server`, then `k3s/install.sh k3s-02`.

### 5. Check the cluster tolerates a failure
Three nodes with control-plane and etcd roles, all `Ready`. Shut down one server VM: `kubectl get nodes` still answers through the stable address, and the stopped node goes `NotReady`. Start it again.

## Verify
`kubectl get nodes -l node-role.kubernetes.io/etcd=true` lists three nodes; the smoke test (`k3s/smoke/run.sh`) passes; the step 5 check passed.

## Undo / rollback
Before step 4, `k3s-03` can be removed: `kubectl drain`, `kubectl delete node k3s-03`, then `k3s-uninstall.sh` on it; etcd drops back to one member. After step 4, restore the `before-ha` snapshot on `k3s-01` with the etcd restore runbook (`runbook-etcd-restore.md`, written in playbook 03, step 8) and reinstall the others.

## Afterwards
Supersede [ADR-0015](../../decisions/0015-k3s-embedded-etcd-server-and-agent.md) (three servers, stable API address) and ADR-0013 (quorum is now automatic). Update `kube-reserved` if the new node is bigger, and the backup jobs for VM `k3s-03`.
