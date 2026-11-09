---
type: playbook
title: Grow the lab to three nodes - pve03's storage and backups, k3s-03, three k3s servers behind kube-vip
description: Finishes pve03 after its join (storage, backups, template, k3s-03 VM), then grows k3s to three etcd servers behind a stable API address and moves the heavy apps off k3s-01.
domain: proxmox
tags: [proxmox, k3s, etcd, kube-vip, storage, backups, capacity]
status: draft
created: 2026-11-07
updated: 2026-11-09
visibility: public
reuse: portable
repo: homelab-infra
depends_on: [../02-proxmox, ../03-k3s, ../04-argocd]
related:
  - ../../docs/decisions/0030-three-node-proxmox-cluster.md
  - ../../docs/decisions/0031-k3s-three-servers-behind-kube-vip.md
  - ../../docs/decisions/0013-two-nodes-without-qdevice.md
  - ../../docs/decisions/0015-k3s-embedded-etcd-server-and-agent.md
  - ../../docs/domains/proxmox/howto-add-node.md
  - ../../docs/domains/k3s/howto-add-server.md
  - ../../docs/domains/proxmox/reference-proxmox.md
blog: candidate
---

# Grow the lab to three nodes

## What you'll have at the end
`pve03` (i7-12700T, 32 GB) is a full member of `pveCluster01`. Its second NVMe is the thin pool `nvme-data`, its VMs back up to `pve01`'s USB disk, and quorum survives any one node going down ([ADR-0030](../../docs/decisions/0030-three-node-proxmox-cluster.md)). k3s has three servers with embedded etcd behind one kube-vip address, so `kubectl`, Argo CD and scheduling keep working when any one node is down. The memory-heavy apps run on the 12 GB `k3s-03`, so `k3s-01` has room again and Backstage has somewhere to go ([ADR-0031](../../docs/decisions/0031-k3s-three-servers-behind-kube-vip.md)).

```
pve01 (8 GB)              pve02 (8 GB)              pve03 (32 GB)
└─ k3s-01  server+etcd    └─ k3s-02  server+etcd    └─ k3s-03  server+etcd
   4 vCPU, 4.5 GB            4 vCPU, 4.5 GB            6 vCPU, 12 GB, on nvme-data
              ╲                   │                   ╱      label homelab.io/size=large
               ╲──────── kube-vip API address :6443 ─╱
                                  ▲
laptop: dev container ── kubectl (kubeconfig points at the VIP)
```

Part A (steps 1 to 6) touches only Proxmox and the new VM, so it's safe while other runs are in progress. **Part B (steps 7 to 12) changes the k3s control plane, moves Hermes and the gateway with their data, and rebuilds `k3s-02`. Plan one sitting for steps 8 to 10.**

## Before you start 🧑
- [ ] `pve03` has joined: `pvecm status` shows `Expected votes: 3` and `Quorate: Yes` ([add a node](../../docs/domains/proxmox/howto-add-node.md), steps 2 to 5). Done 2026-11-07.
- [ ] You've confirmed nothing on `pve03`'s second NVMe (`nvme1n1`, an old BitLocker partition) is needed. Step 3 wipes it.
- [x] The playbook 06 run is closed (2026-11-08).
- [ ] For Part B: you know your router's DHCP range, so you can pick a free address outside it for the k3s API.
- [ ] The `homelab-infra` dev container is running, with OpenCode on the gateway model.

## Kick it off
Paste this into OpenCode from `/workspaces/homelab-infra`:

> Run the playbook `/knowledge/handbook/playbooks/02b-third-node`. Follow `/knowledge/handbook/playbooks/RUNNING.md`. Handbook changes go on a branch in a worktree under `/tmp/agent/`, never in `/knowledge/handbook` itself.

## Steps

### Part A: Proxmox

### 1. Three-node quorum drill 🧑
**Why:** prove that one node down no longer needs `pvecm expected 1` before relying on it. `pve03` has no VMs yet, so it's the one to switch off.
**You do:** in the `pve03` web shell, `shutdown -h now`. Wait a minute, then in the `pve01` shell run `pvecm status | grep -E 'Expected votes|Total votes|Quorate'`. Power `pve03` back on.
**Verify:** with `pve03` off: `Expected votes: 3`, `Total votes: 2`, `Quorate: Yes`. After it's back: `Total votes: 3`, three green nodes in the UI.
**Record:** journal; [runbook-node-down](../../docs/domains/proxmox/runbook-node-down.md) is already rewritten for three nodes. Correct it if reality differs.

### 2. Node-local storage and pve03's backup target 🧑
**Why:** storage entries apply to every node unless restricted. `usb-backup` shows as broken on `pve03`, and `pve03` needs somewhere to back up to that isn't on itself.
**Actions:** the agent prints these for you to run:
- On any node: `pvesm set usb-backup --nodes pve01,pve02` and `pvesm set backup-on-pve01 --nodes pve02,pve03`.
- On `pve01`: add `pve03`'s address (`192.168.86.203`) to the `/mnt/usb-backup` line in `/etc/exports`, with the same options as `pve02`'s entry, then `exportfs -ra` and `exportfs -v`.
**Verify:** on `pve03`, `pvesm status` shows no error, `backup-on-pve01` is `active` and `usb-backup` isn't listed. `touch /mnt/pve/backup-on-pve01/.w && rm /mnt/pve/backup-on-pve01/.w` succeeds.
**Record:** [reference-proxmox](../../docs/domains/proxmox/reference-proxmox.md) (backup storage table).

### 3. Wipe the second NVMe and create `nvme-data` 🧑
**Why:** the second disk becomes a thin pool for VM disks, so `k3s-03` doesn't share the system disk (ADR-0030). This deletes everything on `nvme1n1` and can't be undone.
**You do:** first, in the `pve03` shell, `lsblk -o NAME,SIZE,FSTYPE,MODEL /dev/nvme1n1`: it must be the disk with the BitLocker partition, **not** the one holding `pve-root`. Then in the UI: `pve03` → **Disks** → select `/dev/nvme1n1` → **Wipe Disk** → confirm. Then **Disks → LVM-Thin → Create: Thinpool**: disk `/dev/nvme1n1`, name `nvme-data`, **Add Storage** ticked.
**Verify:** `pvesm status` on `pve03` lists `nvme-data` (`lvmthin`, `active`, about 475 GB). `grep -A4 'lvmthin: nvme-data' /etc/pve/storage.cfg` shows `nodes pve03`; if there's no `nodes` line, run `pvesm set nvme-data --nodes pve03`.
**Record:** reference-proxmox (local VM storage table).

### 4. Debian 13 cloud-init template on pve03 🧑
**Why:** OpenTofu clones `k3s-03` from a template on its own node.
**Actions:** the same script as playbook 02, step 6 (image and checksum checked against `https://cloud.debian.org/images/cloud/trixie/latest/`, QEMU guest agent installed with `virt-customize`), with VM ID `9003` on `pve03`, imported to `local-lvm`.
**Verify:** `qm config 9003` shows `template: 1`, `agent: 1` and a cloud-init drive.
**Record:** reference-proxmox (templates table).

### 5. k3s-03 in OpenTofu
**Why:** the VM is code like the other two. The current module hard-codes 4 cores and `local-lvm`.
**Questions:** size of `k3s-03`. Default 6 vCPU, 12288 MB, 100 GB on `nvme-data`, `192.168.86.213`, VM ID 103 (ADR-0030).
**Actions:** on a branch in `homelab-infra`:
- `tofu/variables.tf`: add `cores = optional(number, 4)` and `datastore = optional(string, "local-lvm")` to the VM object.
- `tofu/main.tf`: `cores = each.value.cores`, and `datastore_id = each.value.datastore` on the disk (cloud-init stays on `local-lvm`).
- `terraform.auto.tfvars.example`: add the `k3s-03` entry (node `pve03`, template `9003`, the answers above).
- 🧑 You add the same `k3s-03` block to your real `tofu/terraform.auto.tfvars`. The agent never opens it.
- `tofu plan`, then `tofu apply` after you've read the plan.
**Verify:** the plan shows **1 to add, 0 to change, 0 to destroy** (the defaults keep `k3s-01` and `k3s-02` unchanged). After apply: `tofu output vm_ips` lists `k3s-03`, and `ssh -i ~/.ssh/homelab debian@192.168.86.213 hostname` answers. PR with CI green, squash-merged.
**Record:** reference-proxmox (k3s VMs table), journal.

### 6. Backup job for k3s-03 🧑
**Why:** every VM is backed up to another node's disk.
**You do:** **Datacenter → Backup → Add**: node `pve03`, storage `backup-on-pve01`, schedule `03:30`, selection VM 103, mode Snapshot, ZSTD, retention keep-daily 7, keep-weekly 4. Then **Run now** once.
**Verify:** the task log ends with `INFO: Backup job finished successfully`. On `pve01`, `df -h /mnt/usb-backup` still has more than 200 GB free.
**Record:** reference-proxmox and [runbook-backup-restore](../../docs/domains/proxmox/runbook-backup-restore.md) (backup job tables).

### Part B: k3s

### 7. Snapshot and a stable API address with kube-vip
**Why:** with three servers, clients shouldn't depend on `k3s-01`'s address. kube-vip moves one virtual IP to whichever server is the leader (ADR-0031).
**Questions:** the VIP. Default: `192.168.86.210`, if it's outside the DHCP range and `ping -c2 192.168.86.210` gets no answer. 🧑 You confirm the DHCP range from the router.
**Actions:**
1. `ssh debian@192.168.86.211 'sudo k3s etcd-snapshot save --name before-ha'`.
2. Look up the current kube-vip release on `https://github.com/kube-vip/kube-vip/releases` and pin it in `k3s/versions.env` (`KUBE_VIP_VERSION`).
3. Add `k3s/kube-vip/`: the RBAC manifest from kube-vip's docs, plus a DaemonSet for control-plane nodes (ARP mode, leader election, `--controlplane`, interface from `ip -br link` on the VM, usually `eth0`), rendered from a template with `K3S_API_VIP`. Put `K3S_API_VIP` in `k3s/nodes.conf` or `versions.env` (it isn't secret).
4. `server.yaml.tmpl`: `tls-san: ["${NODE_IP}", "${K3S_API_VIP}"]`. `install.sh`: copy the rendered kube-vip manifests into `/var/lib/rancher/k3s/server/manifests/` on servers, so k3s deploys them itself, and render `server: https://${K3S_API_VIP}:6443` for joining servers and agents once the VIP answers.
5. `k3s/install.sh k3s-01` to re-render its config with the new SAN and deploy kube-vip.
**Verify:** `kubectl -n kube-system get ds kube-vip-ds` is ready on `k3s-01`; `ping -c2 <VIP>` answers; `curl -sk https://<VIP>:6443/livez` returns `ok` or a 401 (not a TLS name error). PR merged.
**Record:** ADR-0031 (the chosen VIP and version), [howto-add-server](../../docs/domains/k3s/howto-add-server.md) step 2.

### 8. Join k3s-03 as a server
**Why:** the first new etcd member, on the node with room.
**Actions:** `ssh debian@192.168.86.213 'sudo bash -s' < k3s/prepare-node.sh`, add `k3s-03 server` to `k3s/nodes.conf`, `k3s/install.sh k3s-03`. Then `kubectl label node k3s-03 homelab.io/size=large`.
**Verify:** `kubectl get nodes -o wide` shows `k3s-03` `Ready` with `control-plane,etcd` roles; `kubectl get nodes -l homelab.io/size=large` lists it. The cluster now has two etcd members, which tolerate no failure, so carry on with steps 9 and 10 in the same sitting.
**Record:** journal.

### 9. Move the apps and their data off k3s-02 and k3s-01
**Why:** the playbook 06 run put Hermes, the LLM gateway and its Postgres on `k3s-02`, with two `local-path` volumes: `hermes-data` (Hermes' memory and sessions) and Postgres' `data` (the gateway's virtual keys, ADR-0025). A `local-path` volume lives on one node's disk, so rebuilding `k3s-02` in step 10 would lose them. Argo CD and the monitoring Deployments fill `k3s-01` (87 to 95% memory). All of these go to the 12 GB `k3s-03` (ADR-0031).
**Questions:** keep Hermes' memory, or start it fresh? Default: keep it (copy). Postgres is copied too, so the `hermes` virtual key survives without a SOPS edit.
**Actions:**
1. List what is pinned to `k3s-02`: `kubectl get pv -o custom-columns=PV:.metadata.name,CLAIM:.spec.claimRef.name,NS:.spec.claimRef.namespace,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]`. Expect `hermes-data` and `data-postgres-0`. Ask about anything else.
2. A PR in `homelab-gitops`: set the preferred node affinity of Hermes (it points at `k3s-02` since playbook 06), the gateway and Postgres to `homelab.io/size=large` (weight 100). Add the same affinity to the Argo CD repo-server and application-controller, and to the monitoring chart's Deployments (kube-state-metrics, the Alloy singleton). DaemonSets stay everywhere. Merge with CI green.
3. Move each stateful app in turn, Postgres first, then Hermes. The agent:
   1. pauses automated sync on `root` first (it self-heals the child Applications and would undo the next patch), then on the app (`kubectl -n argocd patch application <app> --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'`), and scales the app to 0 (`kubectl -n <ns> scale statefulset/postgres --replicas=0` or `deploy/hermes`);
   2. notes the old volume's folder (`kubectl get pv <pv> -o jsonpath='{.spec.local.path}{.spec.hostPath.path}'`), deletes the PVC (the `Delete=false` annotation from ADR-0032 only stops Argo CD, not `kubectl`) and its PV if it stays `Released`;
   3. syncs the app once (`kubectl -n argocd patch application <app> --type merge -p '{"operation":{"sync":{}}}'`) so Argo CD recreates the PVC, still without automated sync; scales to 1 so the new volume is created on `k3s-03`, then back to 0 and notes the new folder.
4. 🧑 You copy the data in your own shell, old folder to new. Nothing is printed:
   `ssh -i ~/.ssh/homelab debian@192.168.86.212 "sudo tar -C <old-folder> -cpf - ." | ssh -i ~/.ssh/homelab debian@192.168.86.213 "sudo tar -C <new-folder> -xpf -"`
5. The agent scales the app back up, then turns automated sync back on for `root`, which restores the app's own policy from Git. `kubectl rollout restart` the moved Deployments (Argo CD, monitoring) so they reschedule.
**Verify:** `kubectl get pods -A -o wide | grep -E 'hermes|litellm|postgres|argocd|kube-state|alloy'` shows them on `k3s-03` (DaemonSet pods excepted). The gateway accepts Hermes' key: 🧑 DM Hermes in Slack, and it answers. Every Argo CD app is `Synced` and `Healthy`. After 15 minutes, `kubectl top nodes` has `k3s-01` at 75% memory or less; if not, propose a `PreferNoSchedule` taint on `k3s-01` and ask.
**Record:** journal; [lab hardware](../../docs/domains/proxmox/reference-hardware.md) (what fits); ADR-0031 if anything surprised.

### 10. Rebuild k3s-02 as a server
**Why:** etcd needs an odd number of members; three survive one failure. Since step 8 the cluster has two, which tolerate none, so don't leave it there.
**Actions:**
1. Check nothing with a volume is left on it: the PV list from step 9 shows no `k3s-02`.
2. `kubectl drain k3s-02 --ignore-daemonsets --delete-emptydir-data`, `kubectl delete node k3s-02`.
3. `tofu apply -replace='proxmox_virtual_environment_vm.k3s["k3s-02"]'` (check the address with `tofu state list`).
4. `prepare-node.sh` on it, `k3s-02 server` in `nodes.conf`, `k3s/install.sh k3s-02`.
**Verify:** `kubectl get nodes -l node-role.kubernetes.io/etcd=true` lists three nodes, all `Ready`; `k3s/smoke/run.sh` passes; every Argo CD app is `Synced` and `Healthy`.
**Record:** journal.

### 11. Clients on the VIP
**Why:** `kubectl` from the laptop should survive `k3s-01` being down.
**Actions:** change `k3s/kubeconfig.sh` to write `server: https://<VIP>:6443`, and re-run it so the kubeconfig in `%USERPROFILE%\.kube` is refreshed (it's mounted into every dev container, ADR-0017). Then check whether Traefik answers on the VIP too (`curl -s -o /dev/null -w '%{http_code}' http://llm.<VIP>.nip.io/health/liveliness`). If it does, propose moving `LLM_GATEWAY_URL` and the Argo CD UI from `k3s-01`'s address to `<VIP>.nip.io`, so they also survive `k3s-01` being down.
**Verify:** `kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'` shows the VIP; `kubectl get nodes` works.
**Record:** [reference-k3s](../../docs/domains/k3s/reference-k3s.md).

### 12. Failure drill and the monitoring budget 🧑
**Why:** prove the cluster survives losing a server, and that a third node still fits Grafana Cloud's free tier.
**You do:** in the `pve01` shell, `qm shutdown 101`. The agent runs `kubectl get nodes` and `kubectl -n argocd get applications` through the VIP: both answer, and `k3s-01` goes `NotReady`. Then `qm start 101`.
**Actions:** after the restart, `kubectl get nodes` shows three `Ready`. In Grafana Cloud (🧑, **Administration → Usage insights** or the billing dashboard), active series are below the free tier's limit with room to spare.
**Verify:** both checks passed.
**Record:** journal.

## When it's done
- The agent updates [k3s overview](../../docs/domains/k3s/index.md), [reference-k3s](../../docs/domains/k3s/reference-k3s.md), [node maintenance](../../docs/domains/k3s/runbook-node-maintenance.md) (no more "only server") and [howto-add-server](../../docs/domains/k3s/howto-add-server.md) (status `active`, corrected against the run). It sets ADR-0015's `superseded_by` to 0031, and moves ADR-0030 and ADR-0031 to `accepted` once you say so.
- The playbook catalog marks 02b done. The playbook is corrected wherever reality differed.
- Next: playbook 08 (Backstage) has room on `k3s-03`.
