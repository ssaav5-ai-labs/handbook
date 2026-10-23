---
type: playbook
title: Prepare the Proxmox host and create the k3s VM as code
description: Brings pve01 to a clean, updated, backed-up state and creates the single k3s VM from a cloud-init template with OpenTofu, in a new homelab-infra repo.
domain: proxmox
tags: [proxmox, opentofu, cloud-init, backups, infrastructure-as-code]
status: draft
created: 2026-10-23
updated: 2026-10-23
visibility: public
reuse: portable
repo: homelab-infra
depends_on: [../00-workstation-knowledge, ../01-github-foundation]
related:
  - ../../docs/domains/proxmox/reference-hardware.md
  - ../../docs/open-questions/index.md
  - ../../docs/domains/github/howto-rulesets.md
blog: candidate
---

# Prepare the Proxmox host and create the k3s VM as code

## What you'll have at the end
`pve01` on the free update channel, fully updated, with nightly-ready backups to the USB disk. A Debian 13 cloud-init template, and one VM for k3s (4 vCPU, 5 GB RAM, 80 GB) created by OpenTofu from a public `homelab-infra` repo, with CI and branch protection. Rebuilding the VM is one `tofu apply`. Playbook 03 installs k3s on it.

## Before you start 🧑
- [ ] You can open the Proxmox web UI (`https://<pve01-ip>:8006`) and log in as `root`.
- [ ] You know your router's DHCP range, so you can pick a free fixed address for the VM (or set a DHCP reservation for it later).
- [ ] You know what's on the 1 TB USB disk. It gets **formatted** in step 4 unless you say otherwise.
- [ ] Docker Desktop is running. On this 8 GB laptop, stop other dev containers first (`devpod stop handbook`).

## Kick it off
Step 1 creates the repo and its dev container; then, inside it:

> Read `/knowledge/handbook/playbooks/RUNNING.md`, then run the playbook `/knowledge/handbook/playbooks/02-proxmox`.

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
In the container: `git config --global --add safe.directory /knowledge/handbook`, `gh auth login -h github.com -s repo,workflow`, then `opencode` and the kickoff prompt.
**Verify:** The agent runs `git init -b main` (with the identity from playbook 00), adds `README.md`, `AGENTS.md` (pointing to the handbook) and a `.gitignore` covering `.env`, `*.tfstate*`, `.terraform/` and `*.auto.tfvars`, and creates `ssaav5-ai-labs/homelab-infra` (public) with `gh repo create --source . --push`. It checks it can reach the host: `curl -sk https://<pve01-ip>:8006/api2/json/version` returns 401 (reachable, not yet authenticated).
**Record:** Open today's journal entry on a handbook branch.

### 2. Free update channel and updates 🧑
**Why:** Without a subscription, the enterprise repository fails every update. Switching to the no-subscription repository is the supported free path.
**You do (web UI):** `pve01` → Updates → Repositories: **Add** → `No-Subscription` → Add. Select the `pve-enterprise` and Ceph `enterprise` entries → **Disable**. Then Updates → Refresh → **Upgrade** (a console opens; answer `Y`). Reboot if the upgrade installed a new kernel.
**Verify:** Updates → Repositories shows no warnings about enterprise repos; `pveversion` in the host shell shows the new version.
**If pve01 is a laptop or tablet** (it has Wi-Fi and a low-power Y-series CPU): in the host shell, set `HandleLidSwitch=ignore` and `HandleLidSwitchExternalPower=ignore` in `/etc/systemd/logind.conf`, then `systemctl restart systemd-logind`, so closing the lid doesn't suspend the server. The battery then works as a small UPS.
**Record:** Journal: version before and after.

### 3. API access for OpenTofu
**Why:** OpenTofu talks to the Proxmox API with its own least-privilege token, never as root.
**Actions:** The agent prints `pveum` commands for you to run in the host shell (🧑): a user `tofu@pve`, a role `TofuProvisioner` with exactly the privileges the pinned `bpg/proxmox` provider documents for VM management (look them up for the version you pin; PVE 9 renamed some), an ACL for that role on `/`, and an API token `tofu@pve!homelab-infra` with privilege separation off. The token secret is shown once: you paste it straight into `homelab-infra/.env` as `PROXMOX_VE_API_TOKEN='tofu@pve!homelab-infra=<secret>'`, next to `PROXMOX_VE_ENDPOINT=https://<pve01-ip>:8006/` and `PROXMOX_VE_INSECURE=true` (the host still has its self-signed certificate). Never paste the secret into the chat.
**Verify:** `set -a; . ./.env; set +a; curl -sk -H "Authorization: PVEAPIToken=$PROXMOX_VE_API_TOKEN" "${PROXMOX_VE_ENDPOINT}api2/json/nodes" | jq '.data[].node'` prints `"pve01"`. `git check-ignore .env` prints `.env`.
**Record:** `docs/domains/proxmox/reference-proxmox.md` (API user, role, privileges and why; no secrets).

### 4. Backups to the USB disk 🧑
**Why:** Everything later lives on one SSD in one host. Backups are the first thing an SRE sets up, not the last.
**Questions:** Is the USB disk empty or disposable? It's a Seagate One Touch **with password protection**; if the password is enabled it locks on every power cycle and backups fail silently, so turn protection off in Seagate's tool on Windows first (or pick another disk).
**Actions:** The agent prints host-shell commands, and **waits for your explicit "format it"** before you run the destructive part: confirm the disk is `sdb` by size and model with `lsblk`, create one ext4 partition, mount it by UUID at `/mnt/usb-backup` with `nofail` in `/etc/fstab`, and add it as storage: `pvesm add dir usb-backup --path /mnt/usb-backup --content backup --is_mountpoint yes`. Backup jobs are created in step 7, once the VM exists.
**Verify:** `pvesm status` lists `usb-backup` as active; after `umount` and `mount -a` it's still mounted.
**Record:** `reference-proxmox.md` (storage), and a runbook `docs/domains/proxmox/runbook-backup-restore.md` (how to restore a VM from `usb-backup`).

### 5. Debian 13 cloud-init template 🧑
**Why:** Every VM starts from the same small, cloud-init-ready image, so creating or rebuilding one takes seconds.
**Actions:** The agent prints host-shell commands for you to run, with the image URL and checksum checked against `https://cloud.debian.org/images/cloud/trixie/latest/` (`SHA512SUMS`): download `debian-13-genericcloud-amd64.qcow2`, verify it, then create VM 9000 `debian13-cloud` (virtio-scsi-single, the image imported to `local-lvm` as `scsi0`, a cloud-init drive, serial console, QEMU guest agent on) and `qm template 9000`.
**Verify:** VM 9000 shows as a template in the UI; `qm config 9000` shows `scsi0`, `ide2: ...cloudinit` and `agent: 1`.
**Record:** `reference-proxmox.md` (template ID, image version, date).

### 6. The k3s VM with OpenTofu
**Why:** The VM is code: reviewable, repeatable, and rebuilt with one command.
**Questions:** Fixed IP for the VM (recommended: a free address outside the DHCP range), gateway and DNS. VLAN 100 exists on `vmbr0`: what is it for? (Recommended: leave the VM untagged unless you already use that VLAN.) Your SSH public key: create one in PowerShell with `ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\homelab`, then share the `.pub` file's content (public keys are safe to share).
**Actions:** In `tofu/`: `versions.tf` pinning OpenTofu and `bpg/proxmox` (look up the current release; v0.118.0 at time of writing), `main.tf` cloning template 9000 into VM 101 `k3s-01`: CPU type `host`, 4 cores, 5120 MB with ballooning off, 80 GB `scsi0` on `local-lvm` with `discard` and `iothread`, `vmbr0`, start on boot, guest agent on, cloud-init with user `debian`, your public key, the fixed IP, and `package_upgrade`. Real addresses go in `terraform.auto.tfvars` (git-ignored) with a committed `terraform.auto.tfvars.example`. State stays local and git-ignored for now (remote state is an open question).
**Verify:** `tofu fmt -check`, `tofu validate`, then `tofu plan` shows one VM to add. 🧑 You approve `tofu apply`. Then from PowerShell: `ssh -i $env:USERPROFILE\.ssh\homelab debian@<vm-ip> "free -h; nproc; df -h /"` shows about 4.8 GB RAM, 4 CPUs and an 80 GB disk.
**Record:** `reference-proxmox.md` (VM sizing and why it's single-node), an ADR **0013: provision Proxmox VMs with OpenTofu (bpg/proxmox) and a cloud-init template**, and close the "Proxmox provisioning" open question.

### 7. Backup job for the VM 🧑
**Why:** Backups that aren't scheduled don't exist.
**You do (web UI):** Datacenter → Backup → **Add**: storage `usb-backup`, schedule daily 03:00, selection VM 101, mode **Snapshot**, compression ZSTD, retention keep-daily 7, keep-weekly 4. Then select the job → **Run now**.
**Verify:** The task log ends with `TASK OK`, and `usb-backup` → Backups lists one archive for VM 101.
**Record:** Runbook: add the job settings and a tested restore (restore the archive as VM 199, boot it, delete it).

### 8. CI and branch protection for homelab-infra
**Why:** Same change control as the other repos; infrastructure changes especially go through PRs.
**Actions:** `.github/workflows/ci.yml` with one job `ci`: pinned gitleaks CLI (as in the handbook), `tofu fmt -check -recursive`, and `tofu init -backend=false && tofu validate` in `tofu/`. Enable Dependabot, secret scanning and push protection as in playbook 01. Open a PR with everything, and once `ci` is green, add the `protect-main` ruleset with `ci` required (see `howto-rulesets.md`).
**Verify:** CI green; a direct push to `main` is rejected.

### 9. Finish
**Actions:** Close the journal entry (what broke, RAM left on `pve01` per `free -h`). Remind the human to export the session and check it with `grep -cE "sk-or|sk-lf-|PVEAPIToken|=[0-9a-f-]{36}"` before sharing. Open the handbook PR with references, runbook, ADR-0013 and the open-questions update.

## When it's done
- Docs updated: `docs/domains/proxmox/` (reference-proxmox, runbook-backup-restore), ADR-0013, open questions, journal.
- Next playbook: 03 k3s cluster (single node).

## Video
Not recorded yet. Good candidate: step 6 ("a VM as code on an 8 GB homelab").
