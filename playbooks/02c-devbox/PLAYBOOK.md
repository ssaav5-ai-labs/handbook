---
type: playbook
title: Move the dev containers to a devbox VM on pve03
description: A Debian VM with Docker on pve03 runs every repo's dev container through DevPod's SSH provider, so all of them stay up at once and survive the laptop sleeping; the laptop keeps its workspaces as a fallback.
domain: workstation
tags: [workstation, devcontainer, devpod, proxmox, opentofu, tmux]
status: active
created: 2026-11-09
updated: 2026-11-20
visibility: public
reuse: portable
repo: homelab-infra
depends_on: [../02b-third-node]
related:
  - ../../docs/decisions/0033-dev-containers-on-a-devbox-vm.md
  - ../../docs/decisions/0017-kubeconfig-on-windows-mounted-into-containers.md
  - ../../docs/decisions/0030-three-node-proxmox-cluster.md
  - ../../docs/domains/workstation/runbook-daily-start.md
  - ../../docs/domains/workstation/index.md
blog: candidate
---

# Move the dev containers to a devbox VM on pve03

## What you'll have at the end
A VM called `devbox` on `pve03` runs Docker, and every repo's dev container runs there instead of on the laptop ([ADR-0033](../../docs/decisions/0033-dev-containers-on-a-devbox-vm.md)). `handbook`, `homelab-infra`, `homelab-gitops` and `workstation` can all be up at once. You reach each one with `hbx <repo>` (SSH to the devbox, then `docker exec` into the container, inside `tmux`), so an OpenCode run keeps going when the laptop sleeps. The laptop only runs PowerShell, `ssh` and your editors. Docker Desktop and the old workspaces stay installed as the fallback.

```
laptop (PowerShell, ssh, Obsidian)            pve03
   │  hbx handbook                            └─ devbox (VM 110, 4 vCPU, 8 GB, nvme-data)
   │  hbx homelab-infra                            Docker
   └──────────────────────────────────────────►    ├─ handbook-box        ─┐ mounts from /home/debian:
                                                   ├─ homelab-infra-box    │  .kube, .devbox/ssh, .sops-age,
                                                   ├─ homelab-gitops-box   │  code/.../handbook
                                                   └─ workstation-box     ─┘ env from .devbox/env
```

## Before you start 🧑
- [ ] Playbook 02b Part A is done: `nvme-data` exists on `pve03`, template `9003` exists, and `k3s-03` runs. Part B doesn't need to be finished.
- [ ] `192.168.86.214` is free (`ping -c2 192.168.86.214` gets no answer) and outside the router's DHCP range.
- [ ] The password manager is at hand: you'll copy the GitHub token, the gateway URL and key, and the age key from it.
- [ ] You're in the `homelab-infra` dev container (laptop) with OpenCode on the gateway model.

## Kick it off
Paste this into OpenCode from `/workspaces/homelab-infra`:

> Run the playbook `/knowledge/handbook/playbooks/02c-devbox`. Follow `/knowledge/handbook/playbooks/RUNNING.md`. Handbook changes go on a branch in a worktree under `/tmp/agent/`, never in `/knowledge/handbook` itself.

## Steps

### 1. The devbox VM in OpenTofu
**Why:** the devbox is code like the k3s VMs, so it can be rebuilt instead of backed up (ADR-0033).
**Questions:** size. Default: 4 vCPU, 8192 MB, 120 GB on `nvme-data`, VM ID 110, `192.168.86.214`.
**Actions:** on a branch in `homelab-infra`, add `tofu/devbox.tf`. It's a separate `proxmox_virtual_environment_vm.devbox` resource, so the `k3s` map and `install.sh` never see it. It clones template `9003` on `pve03` with the same cloud-init user and key as the k3s VMs, guest agent on, and `on_boot = true`. Add a `devbox` object variable whose defaults are the sizes above (so the real `terraform.auto.tfvars` needs no change) and its block in `terraform.auto.tfvars.example`. 🧑 In your own shell, load the Proxmox token first, or the provider fails with *Missing Proxmox VE API Endpoint*: `cd /workspaces/homelab-infra && set -a && . ./.env && set +a`, then `cd tofu && tofu plan` and `tofu apply`.
**Verify:** the plan shows **1 to add, 0 to change, 0 to destroy**. `ssh -i ~/.ssh/homelab debian@192.168.86.214 hostname` prints `devbox`. PR with CI green, squash-merged.
**Record:** [reference-proxmox](../../docs/domains/proxmox/reference-proxmox.md) (a VM table row, with "no backup job" and why).

### 2. Docker and tmux on the devbox
**Why:** DevPod's SSH provider needs Docker on the host. tmux on the host is handy for maintenance.
**Actions:** add `devbox/prepare.sh` to `homelab-infra`. It sets up Docker's apt repository for Debian 13 with the signing key, installs `docker-ce`, `docker-ce-cli`, `containerd.io` and `docker-buildx-plugin` at the version looked up on Docker's release notes and pinned in the script, and adds `debian` to the `docker` group. It also installs `git`, `tmux` and `rsync`, and creates `~/.devbox/ssh`, `~/.kube`, `~/.sops-age` (all `700`) and `~/code/github.com/ssaav5-ai-labs`. Run it with `ssh -i ~/.ssh/homelab debian@192.168.86.214 'sudo bash -s' < devbox/prepare.sh`, then reconnect so the group applies.
**Verify:** `ssh -i ~/.ssh/homelab debian@192.168.86.214 'docker run --rm hello-world | head -2; id -u; tmux -V'` shows the hello message, `1000` and a tmux version.
**Record:** journal.

### 3. Secrets onto the devbox 🧑
**Why:** the containers on the devbox can't see Windows. Their kubeconfig, SSH key, age key and tokens live on the devbox, put there by you. The agent only checks that they exist (RUNNING.md: never print a secret).
**You do:** in **PowerShell** on the laptop, one at a time:
```
scp -i $env:USERPROFILE\.ssh\homelab $env:USERPROFILE\.kube\config debian@192.168.86.214:.kube/config
scp -i $env:USERPROFILE\.ssh\homelab $env:USERPROFILE\.ssh\homelab debian@192.168.86.214:.devbox/ssh/homelab
scp -i $env:USERPROFILE\.ssh\homelab $env:USERPROFILE\.sops-age\keys.txt debian@192.168.86.214:.sops-age/keys.txt
ssh -i $env:USERPROFILE\.ssh\homelab debian@192.168.86.214
```
In that SSH session, create the env file and paste the three values from the password manager:
```
nano ~/.devbox/env
```
It needs three lines, with no quotes and no spaces around `=`: `GH_TOKEN=...`, `LLM_GATEWAY_URL=...` and `LLM_GATEWAY_KEY=...`. Save, then:
```
chmod 600 ~/.devbox/env ~/.kube/config ~/.devbox/ssh/homelab ~/.sops-age/keys.txt && exit
```
**Verify:** the agent runs `ssh -i ~/.ssh/homelab debian@192.168.86.214 'cut -d= -f1 ~/.devbox/env; stat -c "%a %n" ~/.kube/config ~/.devbox/ssh/homelab ~/.sops-age/keys.txt ~/.devbox/env; grep -c "$(printf "\r")" ~/.devbox/env'`. That prints the three key names, four `600` lines, and `0` (no Windows line endings).
**Record:** journal (no values).

### 4. The handbook clone on the devbox
**Why:** every container mounts the handbook at `/knowledge/handbook` (ADR-0033 keeps that path).
**Actions:** `ssh -i ~/.ssh/homelab debian@192.168.86.214 'git clone https://github.com/ssaav5-ai-labs/handbook.git ~/code/github.com/ssaav5-ai-labs/handbook'`. The repo is public, so this needs no token; pushes happen from inside the containers, with `GH_TOKEN`.
**Verify:** `ssh ... 'git -C ~/code/github.com/ssaav5-ai-labs/handbook log --oneline -1'` matches `main` on GitHub.
**Record:** journal.

### 5. The devbox dev container definition
**Why:** the existing `devcontainer.json` mounts Windows paths (`${localEnv:USERPROFILE}`), which don't exist on the devbox. A second definition points at the devbox paths and keeps the laptop one working.
**Actions:**
1. In `workstation`: add `devcontainer/devbox/devcontainer.json`. It uses the same `build` (Dockerfile at `../Dockerfile`), features and `postCreateCommand` as `devcontainer/devcontainer.json`, with these changes:
   - `"runArgs": ["--env-file=/home/debian/.devbox/env"]`, and `containerEnv` keeps only `SOPS_AGE_KEY_FILE`;
   - `mounts`: the `opencode-data` volume, plus binds `/home/debian/.kube` → `/home/vscode/.kube`, `/home/debian/.devbox/ssh` → `/home/vscode/.ssh`, `/home/debian/.sops-age` → `/home/vscode/.sops-age` and `/home/debian/code/github.com/ssaav5-ai-labs/handbook` → `/knowledge/handbook`;
   - drop the `homelab-ssh` volume and the `chown`/`chmod` of `.ssh` from `postCreateCommand`, because the bind keeps the devbox's permissions.

   Add `tmux` to the Dockerfile's packages. PR with CI green, squash-merged.
2. In `handbook`, `homelab-infra` and `homelab-gitops`: the same file as `.devcontainer/devbox/devcontainer.json`, with `build` pointing at that repo's own Dockerfile. Keep any repo-specific mounts or env, translated to devbox paths. One PR per repo.
**Verify:** each PR's CI is green, and `git diff` against the laptop definition shows only the mounts, `runArgs`/`containerEnv` and `postCreateCommand` lines.
**Record:** [workstation overview](../../docs/domains/workstation/index.md) (the two definitions and why).

### 6. DevPod's SSH provider and the first workspace 🧑
**Why:** DevPod on the laptop drives Docker on the devbox over SSH. Its `<id>.devpod` SSH entries don't work on Windows with this provider (they wait for the DevPod agent and time out after about 5 minutes; seen 2026-11-20 with DevPod on Windows), so you enter the containers with `docker exec` over plain SSH instead, the same trick the laptop runbook uses.
**You do:** in **PowerShell**, add a host entry so DevPod and `ssh` find the devbox and its key. Run `notepad $env:USERPROFILE\.ssh\config` and add:
```
Host devbox
  HostName 192.168.86.214
  User debian
  IdentityFile ~/.ssh/homelab
```
Check it with `ssh devbox hostname`, which should print `devbox`. Then, one at a time:
```
devpod provider add ssh --name devbox -o HOST=devbox
devpod up github.com/ssaav5-ai-labs/homelab-infra --provider devbox --id homelab-infra-box --devcontainer-path .devcontainer/devbox/devcontainer.json --ide none
ssh devbox docker ps -q --filter "volume=/workspaces/homelab-infra-box"
ssh -t devbox docker exec -it -u vscode -w /workspaces/homelab-infra-box <id> tmux new -A -s main
```
Use the ID the third command prints. DevPod names the folder after the workspace ID, so it is `/workspaces/<repo>-box`, not `/workspaces/<repo>`.
The agent looks up the SSH provider's current options on DevPod's docs first and corrects the commands if they have changed.
**Verify:** inside the new container. The devbox's `~/.devbox/ssh` holds only the key, so first give it the lab's host keys (once; every workspace shares the file):
```
ssh-keyscan -t ed25519 192.168.86.201 192.168.86.202 192.168.86.203 192.168.86.211 192.168.86.212 192.168.86.213 192.168.86.214 >> ~/.ssh/known_hosts 2>/dev/null
echo "$LLM_GATEWAY_URL ${LLM_GATEWAY_KEY:+key set} ${GH_TOKEN:+gh set}"
kubectl get nodes
ssh -i ~/.ssh/homelab -o BatchMode=yes debian@192.168.86.211 true && echo ssh-ok
test -r "$SOPS_AGE_KEY_FILE" && echo age-ok
gh auth status 2>&1 | head -2
ls /knowledge/handbook/playbooks
```
You should see the URL with `key set gh set`, the nodes, `ssh-ok`, `age-ok`, gh logged in, and the playbook list.
**Record:** journal.

### 7. The other workspaces, and the tmux check 🧑
**Why:** prove all four fit at once, and that a run survives a dropped connection.
**You do:** the same `devpod up` for `handbook`, `homelab-gitops` and `workstation` (ids `<repo>-box`). In `homelab-infra-box`, start `opencode`, then close the PowerShell window. Open a new one and run `hbx homelab-infra` (step 8 adds it to your profile; until then, the `docker exec` line from step 6): OpenCode is still there.
**Verify:** `ssh devbox 'docker ps -q | wc -l; free -m | sed -n 2p'` shows four containers and more than 1.5 GB available. In each container, `opencode` starts on the gateway model (`echo $LLM_GATEWAY_URL` isn't empty), and a test branch push works (`git push --dry-run origin HEAD`).
**Record:** journal; the memory figures in ADR-0033 if they differ.

### 8. The new daily start
**Why:** the runbook has to match what you now do every day.
**Actions:** update [runbook-daily-start](../../docs/domains/workstation/runbook-daily-start.md):
- **Start:** `hbx <repo>` (or `hb` for the handbook). It runs `devpod up <repo>-box` itself when the container isn't running, for example after a devbox reboot.
- **Second shell (for `sops edit`):** a second window in the same tmux session (`Ctrl+b c`), or the `docker exec` line with `tmux new -A -s human`.
- **Stop:** nothing to do. Optionally `devpod stop <repo>-box`.
- **Handbook on Windows:** `git pull` before editing in Obsidian or OpenKnowledge.
- **Fallback when `pve03` is down:** start Docker Desktop and use the laptop workspaces as before.

Replace the `hb` function in both PowerShell profiles with `hbx` and `hb` from the runbook, and keep the old laptop function as `hbl <repo>`, without the laptop gateway line. Remove `GH_TOKEN`, `LLM_GATEWAY_*` from the "Env vars empty" fix row for the devbox (they come from `~/.devbox/env`).
**Verify:** you follow the new runbook from a fresh PowerShell window with Docker Desktop **not** running, and reach OpenCode in `handbook-box`.
**Record:** the runbook; journal.

## When it's done
- ADR-0033 goes to `accepted` once you say so; ADR-0017 gets a line saying it's now the laptop fallback (amended by 0033).
- [Lab hardware](../../docs/domains/proxmox/reference-hardware.md) and [reference-proxmox](../../docs/domains/proxmox/reference-proxmox.md) list the devbox, and what's left spare on `pve03`.
- The playbook catalog marks 02c done, and the playbook is corrected wherever reality differed.
