---
type: playbook
title: Harden the two-node Proxmox cluster and create the k3s VMs as code
description: Updates pve01 and pve02, prepares for running two nodes without a tie-breaker, sets up cross-node backups, and creates one k3s VM per node from cloud-init templates with OpenTofu, in a new homelab-infra repo.
domain: proxmox
tags: [proxmox, cluster, quorum, opentofu, cloud-init, backups, infrastructure-as-code]
status: draft
created: 2026-10-23
updated: 2026-10-27
visibility: public
reuse: portable
repo: homelab-infra
depends_on: [../00-workstation-knowledge, ../01-github-foundation]
related:
  - ../../docs/domains/proxmox/reference-hardware.md
  - ../../docs/decisions/0013-two-nodes-without-qdevice.md
  - ../../docs/domains/proxmox/howto-add-node.md
  - ../../docs/open-questions/index.md
  - ../../docs/domains/github/howto-rulesets.md
blog: candidate
---

# Harden the two-node Proxmox cluster and create the k3s VMs as code

## What you'll have at the end
`pveCluster01` with two nodes (`pve01`, `pve02`) on the free update channel and fully updated, with a tested runbook for keeping control when one node is down ([ADR-0013](../../docs/decisions/0013-two-nodes-without-qdevice.md)). Each node's VM is backed up to the USB disk on the **other** node. One k3s VM per node, created by OpenTofu from a public `homelab-infra` repo with CI and branch protection. Rebuilding any VM is one `tofu apply`. Playbook 03 installs k3s on them.

A third node comes later and is a join, not a rebuild: [add a Proxmox node](../../docs/domains/proxmox/howto-add-node.md). Steps 4 to 8 work on whichever nodes are in the cluster, so re-running this playbook after a join picks the new node up.

## Before you start 🧑
- [ ] You can log in to the Proxmox web UI of `pve01` as `root`.
- [ ] You know your router's DHCP range, so you can pick free fixed addresses for the two VMs.
- [ ] You know what's on the two 1 TB USB disks (on `pve01` and `pve02`). They get **formatted** in step 5 unless you say otherwise.
- [ ] Docker Desktop is running. On this 8 GB laptop, run one dev container at a time: stop the others only when no agent is working in them.

## Kick it off
Step 1 creates the repo and its dev container; then, inside it:

> Read `/knowledge/handbook/playbooks/RUNNING.md`, then run the playbook `/knowledge/handbook/playbooks/02-proxmox`.

If you're resuming an earlier run, say so: the agent checks each step's Verify first and skips what's done.

## Steps

### 1. Create the homelab-infra repo and open it 🧑
**Why:** Infrastructure code gets its own repo (ADR-0003 layout), built from the base dev container, which already has `tofu`, `sops`, `age` and `kubectl`.
**You do (PowerShell):**
```powershell
$r = "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\homelab-infra"
New-Item -ItemType Directory -Force "$r\.devcontainer" | Out-Null
Copy-Item "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\workstation\devcontainer\*" "$r\.devcontainer\"
Copy-Item "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\handbook\opencode.json" $r
devpod up $r --ide none
$c = docker ps --format "{{.ID}} {{.Image}}" | Select-String "vsc-homelab-infra" | ForEach-Object { $_.Line.Split(" ")[0] } | Select-Object -First 1
docker exec -it -u vscode -w /workspaces/homelab-infra $c bash
```
In the container, one at a time: `gh auth login -h github.com -s repo,workflow` (after entering the code on github.com, click the final green **Authorize** button), then `git config --global --add safe.directory /knowledge/handbook`, then `opencode` and the kickoff prompt.
**Verify:** The agent runs `git init -b main` (with the identity from playbook 00), adds `README.md`, `AGENTS.md` (pointing to the handbook) and a `.gitignore` covering `.env`, `*.tfstate*`, `.terraform/` and `*.auto.tfvars`, and creates `ssaav5-ai-labs/homelab-infra` (public) with `gh repo create --source . --push`. It checks it can reach the cluster: `curl -sk https://<pve01-ip>:8006/api2/json/version` returns 401 (reachable, not yet authenticated).
**Record:** Open today's journal entry on a handbook branch.

### 2. Free update channel and updates on pve01 and pve02 🧑
**Why:** Without a subscription, the enterprise repository fails every update. The no-subscription repository is the supported free path. Repositories are set per node.
**You do (web UI), for `pve01` and then `pve02`:** node → Updates → Repositories: **Add** → `No-Subscription` → Add. Select the `pve-enterprise` and Ceph `enterprise` entries → **Disable**. Then Updates → Refresh → **Upgrade** (answer `Y`). Reboot one node at a time if a new kernel was installed, and wait until it's back (green in the tree) before the next.
**If a node is a laptop or tablet** (Wi-Fi plus a battery): in its shell, set `HandleLidSwitch=ignore` and `HandleLidSwitchExternalPower=ignore` in `/etc/systemd/logind.conf`, then `systemctl restart systemd-logind`, so closing the lid doesn't suspend it. The battery then works as a small UPS.
**Verify:** `pveversion` on both nodes shows the same, newer version; Datacenter → Cluster shows both nodes online.
**Record:** Journal: versions before and after.

### 3. Two nodes without a tie-breaker: know the failure mode 🧑
**Why:** Each node has one vote and the cluster needs a majority, which with two votes means both. While either node is down, the survivor loses quorum: running VMs keep running, but `/etc/pve` turns read-only, so you can't start, stop, create or change VMs there. That's an accepted trade-off until a third node arrives ([ADR-0013](../../docs/decisions/0013-two-nodes-without-qdevice.md)); a known manual fix makes it a two-minute job instead of a surprise.
**Rules for now:**
- Reboot one node at a time and wait until it's green again before touching the other.
- No Proxmox HA (Datacenter → HA stays empty): without quorum, HA would fence (reboot) the surviving node.
- Don't edit `corosync.conf` for `two_node` mode; it isn't a supported Proxmox setup.
**If a node is down and you need control on the other:** on the surviving node, `pvecm expected 1`. It lowers the expected votes until the other node rejoins, after which corosync goes back to 2 on its own. Use it only when the other node is really off (never while both run but can't see each other, or both sides may change the same VM).
**Verify:** `pvecm status` shows `Nodes: 2`, `Expected votes: 2`, `Quorate: Yes`. Optional drill: shut down `pve02`; on `pve01`, `pvecm status` shows `Quorate: No` and starting a VM fails; run `pvecm expected 1`, now it shows `Quorate: Yes`; start `pve02` again and check `Expected votes` is back to 2. If an earlier run set up a QDevice, `pvecm qdevice remove` first.
**Record:** `docs/domains/proxmox/runbook-node-down.md` (the rules and the `pvecm expected 1` fix), and the journal (drill result).

### 4. API access for OpenTofu
**Why:** OpenTofu talks to the Proxmox API with its own least-privilege token, never as root. Users and tokens are cluster-wide, so one token covers every node, including any node that joins later.
**Actions:** If no token exists yet, the agent prints `pveum` commands for you to run on any node (🧑): user `tofu@pve`, role `TofuProvisioner` with exactly the privileges the pinned `bpg/proxmox` provider documents for VM management (look them up for the version you pin; PVE 9 renamed some), an ACL for that role on `/`, and token `tofu@pve!homelab-infra` with privilege separation off. The token secret is shown once. Write it into `homelab-infra/.env` from the container's terminal (not inside the agent) without it touching the screen:
```bash
git check-ignore .env            # must print .env
read -rp 'pve01 IP address: ' IP
read -rsp 'Paste the token secret (hidden): ' T; echo
printf '%s\n' "PROXMOX_VE_ENDPOINT=https://$IP:8006/" "PROXMOX_VE_INSECURE=true" > .env
printf 'PROXMOX_VE_API_TOKEN=tofu@pve!homelab-infra=%s\n' "$T" >> .env
chmod 600 .env; unset T
```
`PROXMOX_VE_INSECURE=true` is there because the nodes still use self-signed certificates.
**Verify:** `set -a; . ./.env; set +a; curl -sk -H "Authorization: PVEAPIToken=$PROXMOX_VE_API_TOKEN" "${PROXMOX_VE_ENDPOINT}api2/json/nodes" | jq -r '.data[].node'` prints `pve01` and `pve02` (and any node that joined later).
**Record:** `docs/domains/proxmox/reference-proxmox.md` (API user, role, privileges and why; no secrets).

### 5. Cross-node backups on the USB disks 🧑
**Why:** Backups that sit on the same machine as the VM die with it. Every VM backs up to a disk on a different node.
**Questions:** Are both USB disks empty or disposable? They're Seagate One Touch drives **with password protection**: if a password is enabled, the disk locks on every power cycle and backups fail silently, so turn protection off in Seagate's tool on Windows first.
**Plan:**

| Storage | Disk on | Used by (backs up its VM there) |
|---|---|---|
| `backup-on-pve01` | `pve01` | `pve02` (and a third node later) |
| `backup-on-pve02` | `pve02` | `pve01` |

**Actions:** The agent prints host-shell commands for each disk node and **waits for your explicit "format it"** before you run the destructive part:
- Confirm the disk by size and model with `lsblk`, create one ext4 partition, mount it by UUID at `/mnt/usb-backup` with `nofail` in `/etc/fstab`.
- Share it over NFS to the nodes that use it only (`nfs-kernel-server`, one `/etc/exports` line per using node's address, `no_root_squash` for those addresses only, since Proxmox writes backups as root).
- Add it as cluster storage restricted to those nodes: `pvesm add nfs backup-on-pve02 --server <pve02-ip> --export /mnt/usb-backup --content backup --nodes pve01`, and `backup-on-pve01 ... --nodes pve02`.
- **When a third node joins:** add its address to the export on `pve01` (`exportfs -ra`), then `pvesm set backup-on-pve01 --nodes pve02,<new-node>`.

**Verify:** `pvesm status` on each node lists its backup target as active; after a reboot of a disk node, its mount and export come back on their own.
**Record:** `reference-proxmox.md` (storage and why cross-node), and a runbook `docs/domains/proxmox/runbook-backup-restore.md`.

### 6. Debian 13 cloud-init template on each node 🧑
**Why:** Every VM starts from the same small, cloud-init-ready image. `local-lvm` isn't shared between nodes, so each node gets its own copy of the template.
**Actions:** The agent prints one script, with the image URL and checksum checked against `https://cloud.debian.org/images/cloud/trixie/latest/` (`SHA512SUMS`), that you run on each node with its own VM ID: `9001` on `pve01`, `9002` on `pve02` (`9003` on a third node later). It downloads and verifies `debian-13-genericcloud-amd64.qcow2`, creates the VM `debian13-cloud` (virtio-scsi-single, the image imported to `local-lvm` as `scsi0`, a cloud-init drive, serial console, QEMU guest agent on) and runs `qm template`.
**Verify:** Each node shows its template in the UI; `qm config <id>` shows `scsi0`, `ide2: ...cloudinit` and `agent: 1`.
**Record:** `reference-proxmox.md` (template IDs, image version, date).

### 7. The k3s VMs with OpenTofu
**Why:** The VMs are code: reviewable, repeatable, and rebuilt with one command. One VM per node: playbook 03 makes `k3s-01` the server (control plane) and `k3s-02` an agent, so apps can keep running when `pve02` is down.
**Questions:** Fixed IPs for the two VMs (free addresses outside the DHCP range), gateway and DNS. Your SSH public key: create one in PowerShell with `ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\homelab`, then share the `.pub` file's content (public keys are safe to share).
**Actions:** In `tofu/`: `versions.tf` pinning OpenTofu and `bpg/proxmox` (look up the current release; v0.118.0 at time of writing). A `for_each` over a map of VMs, each cloning its own node's template:

| VM | ID | Node | vCPU | RAM | Disk |
|---|---|---|---|---|---|
| `k3s-01` | 101 | pve01 | 4 | 4608 MB | 60 GB |
| `k3s-02` | 102 | pve02 | 4 | 4608 MB | 60 GB |

4.5 GB leaves about 2 GB per host for Proxmox itself and the backup traffic; `free -h` on the hosts confirms it in Verify. A third node later is a one-entry change to the map and a `tofu apply` that leaves the other VMs untouched.
All VMs: CPU type `host`, ballooning off, `scsi0` on `local-lvm` with `discard` and `iothread`, `vmbr0`, start on boot, guest agent on, cloud-init user `debian` with your public key, the fixed IP, and `package_upgrade`. Real addresses go in `terraform.auto.tfvars` (git-ignored) with a committed `terraform.auto.tfvars.example`. State stays local and git-ignored for now (remote state is an open question).
**Verify:** `tofu fmt -check`, `tofu validate`, then `tofu plan` shows two VMs to add. 🧑 You approve `tofu apply`. Then from PowerShell, for each VM: `ssh -i $env:USERPROFILE\.ssh\homelab debian@<vm-ip> "hostname; free -h; nproc; df -h /"`. On `pve01`/`pve02`, `free -h` in the host shell still shows at least 700 MB available.
**Record:** `reference-proxmox.md` (VM sizing and why), an ADR **0014: provision Proxmox VMs with OpenTofu (bpg/proxmox) and per-node cloud-init templates**, and close the "Proxmox provisioning" open question.

### 8. Backup jobs 🧑
**Why:** Backups that aren't scheduled don't exist.
**You do (web UI):** Datacenter → Backup → **Add**, one job per storage:
- VM 101 → `backup-on-pve02`; VM 102 → `backup-on-pve01`.
- All: daily 03:00, mode **Snapshot**, compression ZSTD, retention keep-daily 7, keep-weekly 4.
Then select each job → **Run now**.
**Verify:** Each task log ends with `TASK OK`, and each backup storage lists the expected archives.
**Record:** Runbook: the job settings and a tested restore (restore `k3s-01`'s archive as VM 199 on `pve02`, boot it, delete it; stop `k3s-02` first if `pve02` runs short of RAM).

### 9. CI and branch protection for homelab-infra
**Why:** Same change control as the other repos; infrastructure changes especially go through PRs.
**Actions:** `.github/workflows/ci.yml` with one job `ci`: pinned gitleaks CLI (as in the handbook), `tofu fmt -check -recursive`, and `tofu init -backend=false && tofu validate` in `tofu/`. Enable Dependabot, secret scanning and push protection as in playbook 01. Open a PR with everything, and once `ci` is green, add the `protect-main` ruleset with `ci` required (see `howto-rulesets.md`).
**Verify:** CI green; a direct push to `main` is rejected.

### 10. Finish
**Actions:** Close the journal entry (what broke, RAM left on each node per `free -h`, the quorum drill). Remind the human to export the session and check it with `grep -cE "sk-or|sk-lf-|PVEAPIToken|=[0-9a-f-]{36}"` before sharing. Open the handbook PR with references, runbook, ADR-0014 and the open-questions update.

## When it's done
- Docs updated: `docs/domains/proxmox/` (reference-proxmox, reference-hardware, runbook-backup-restore, runbook-node-down), ADR-0014, open questions, journal.
- Next playbook: 03 k3s cluster (server on `k3s-01` with embedded etcd, agent on `k3s-02`).

## Video
Not recorded yet. Good candidates: step 3 ("what a two-node Proxmox cluster does when a node dies") and step 7 ("the k3s VMs as code").
