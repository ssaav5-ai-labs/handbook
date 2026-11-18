---
type: adr
title: Run the dev containers on a devbox VM on pve03, with the laptop as a thin client
description: A Debian VM on pve03 runs Docker, and DevPod's SSH provider puts every repo's dev container there, so all of them can stay up at once and keep running while the laptop sleeps; secrets and the handbook clone live on the devbox, and the laptop's Docker Desktop becomes the fallback.
domain: workstation
tags: [workstation, devcontainer, devpod, proxmox, capacity, secrets]
status: proposed
created: 2026-11-09
updated: 2026-11-09
visibility: public
reuse: portable
related: [0017-kubeconfig-on-windows-mounted-into-containers.md, 0030-three-node-proxmox-cluster.md, 0006-local-repo-layout.md, 0020-secrets-in-git-with-sops-age-ksops.md, ../domains/workstation/index.md, ../domains/workstation/runbook-daily-start.md, ../../playbooks/02c-devbox/PLAYBOOK.md]
supersedes: []
superseded_by: []
amends: [0017-kubeconfig-on-windows-mounted-into-containers.md]
blog: candidate
---

# 0033. Run the dev containers on a devbox VM on pve03, with the laptop as a thin client

## Context
Every repo has a dev container, run by DevPod on Docker Desktop on the Windows laptop (ADR-0017). The laptop has 8 GB soldered, so only one container fits at a time. A playbook that touches two repos means stopping one container and starting another in the middle of a run (playbook 02b did this on 2026-11-09). Long OpenCode runs also stop when the laptop sleeps. `pve03` (ADR-0030) has about 17 GB spare after `k3s-03`.

## Options considered
1. **Stay on the laptop:** nothing to build; still one container at a time, and runs stop with the lid.
2. **One container on a remote host with every repo inside it:** a single always-on environment; but it breaks the one-repo-one-container convention, so every repo's tools and pins end up mixed.
3. **A devbox VM with Docker on pve03, and DevPod's SSH provider:** the same per-repo dev containers, now on a 32 GB host. Each workspace is cloned from GitHub onto the devbox. The laptop runs `ssh` and an editor. Costs about 8 GB of `pve03`, and the secrets move onto the devbox.
4. **Dev containers as pods on k3s (DevPod's Kubernetes provider):** no extra VM, but every workspace competes with the lab's own apps for memory, and an outage of the cluster takes the tools needed to fix it with it.

## Decision
Option 3, proposed on 2026-11-09 for Shawn's acceptance.
- **The VM:** `devbox`, VM 110 on `pve03`, 4 vCPU, 8 GB, 120 GB on `nvme-data`, `192.168.86.214`. Cloned from template `9003` and defined in `homelab-infra/tofu` next to the k3s VMs. Docker CE comes from Docker's apt repository with a pinned version.
- **The workspaces:** DevPod on the laptop gets an SSH provider `devbox`. Workspaces are created from the GitHub URL, with IDs `<repo>-box`, so the laptop workspaces stay as a fallback. Each repo gets a second dev container definition, `.devcontainer/devbox/devcontainer.json`, from the template in `workstation/devcontainer/devbox/`. It uses the same image and features, with mounts that point at paths on the devbox instead of `%USERPROFILE%`.
- **Secrets and mounts (amends ADR-0017 for the devbox):**
  - The kubeconfig is at `/home/debian/.kube`, the lab SSH key at `/home/debian/.devbox/ssh` and the age key at `/home/debian/.sops-age`, all mode 600, bind-mounted at the same container paths as today. The `debian` and `vscode` users are both UID 1000, so Linux permissions carry through.
  - `GH_TOKEN`, `LLM_GATEWAY_URL` and `LLM_GATEWAY_KEY` come from `/home/debian/.devbox/env` through Docker's `--env-file`, instead of Windows user variables.
  - The human puts every secret there from the password manager. Agents only check key names.
- **The handbook:** a clone at `/home/debian/code/github.com/ssaav5-ai-labs/handbook`, bind-mounted at `/knowledge/handbook` as today. The Windows clone stays for Obsidian and OpenKnowledge. GitHub `main` is the source of truth, so either clone pulls before editing.
- **Sessions:** `tmux` in the base image. The daily start becomes `ssh -t <repo>-box.devpod tmux new -A -s main`, so an OpenCode run survives a closed lid or a dropped connection.
- **No Proxmox backup of the devbox.** It's rebuilt from Git and the password manager. Work in progress is pushed to a branch, not kept only on the devbox.

## Consequences
- All repos can be up at once. Switching repos is another `ssh`, with nothing to stop or start, and the laptop no longer needs Docker Desktop running, which frees 2 to 3 GB.
- `pve03` keeps about 9 GB spare after `k3s-03` and the devbox. Backstage goes on `k3s-03` and doesn't need it.
- A `pve03` outage now takes the dev environment down too. The fallback is the laptop's existing workspaces (ADR-0017), which are kept working.
- The devbox holds cluster-admin and SOPS credentials on an unencrypted VM disk. It accepts SSH keys only, and it isn't backed up, so those credentials don't end up on a USB disk.
- Working away from home needs a way into the LAN. That's the existing open question on private remote access (Tailscale).
- Each repo carries two dev container definitions until the laptop path is retired. They share the Dockerfile, so tool versions can't drift.

## In a team or enterprise setting
This is the shape of a cloud development environment (Codespaces, Coder, DevPod on a shared cluster or VMs). Each developer gets a workspace on central compute, defined by the repo's `devcontainer.json`. Secrets are injected from a vault per workspace with short-lived tokens, not files on a VM, and idle workspaces are stopped automatically to save cost.
