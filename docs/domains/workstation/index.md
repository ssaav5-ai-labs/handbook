---
type: explanation
title: Workstation
description: Overview of the workstation domain - what exists, how it fits, links to how-tos, runbooks and decisions.
domain: workstation
status: draft
visibility: public
reuse: lab-specific
created: 2026-10-20
updated: 2026-10-22
---

# Workstation

## What's installed

The base devcontainer (`Dockerfile` + `devcontainer.json`, see the [workstation repo](https://github.com/ssaav5-ai-labs/workstation)) bakes in every tool a code repo is likely to need:

| Tool | Version | Why |
|---|---|---|
| Python | 3.12 | Scripting, mkdocs, infrastructure tooling |
| Node.js | 24 | Agent harnesses (OpenCode), OpenKnowledge CLI |
| GitHub CLI | latest | PRs, releases, Actions from the container |
| kubectl | latest stable | k3s cluster management |
| helm | latest stable | Helm chart operations |
| OpenTofu | 1.11.0 | Infrastructure as code (open-source Terraform fork) |
| sops | 3.13.3 | Encrypted secrets in git (AGE backend) |
| age | 1.3.2 | SOPS encryption backend |
| k9s | 0.40.10 | Terminal-based cluster dashboard |
| argocd | 3.5.6 | Argo CD CLI (matches server version) |
| kubeconform | 0.8.0 | Kubernetes manifest validation (matches CI) |

Every devcontainer also mounts the handbook at `/knowledge/handbook` (read-write, cached), so any agent in any repo can read ADRs, record journal entries, and follow playbooks without a separate clone.

### Persistent kubeconfig, SSH key and age key

Three mounts keep cluster access, the lab SSH key and the SOPS age key across container rebuilds, per [ADR-0017](../../decisions/0017-kubeconfig-on-windows-mounted-into-containers.md) and [ADR-0020](../../decisions/0020-secrets-in-git-with-sops-age-ksops.md):

- **kubeconfig:** `%USERPROFILE%\.kube` is bind-mounted to `/home/vscode/.kube`. Windows bind mounts show every file as world-readable, which is fine for a kubeconfig (kubectl doesn't check permissions).
- **SSH key:** A named Docker volume `homelab-ssh` mounts to `/home/vscode/.ssh`. The SSH key can't live on a Windows bind mount because `ssh` refuses keys that are world-readable.
- **Age key:** `%USERPROFILE%\.sops-age` is bind-mounted to `/home/vscode/.sops-age`. SOPS and age don't check file permissions, so the bind mount is fine. The path is set in `SOPS_AGE_KEY_FILE=/home/vscode/.sops-age/keys.txt`. The key is created once by `age-keygen` and copied to the password manager.

The `postCreateCommand` fixes ownership: `sudo chown vscode:vscode /home/vscode/.ssh && chmod 700 /home/vscode/.ssh`.

The key is copied into the volume once after the first container rebuild with the new mount:
```powershell
docker cp "$env:USERPROFILE\.ssh\homelab" "${c}:/home/vscode/.ssh/homelab"
docker exec -u root $c chown vscode:vscode /home/vscode/.ssh/homelab
docker exec -u root $c chmod 600 /home/vscode/.ssh/homelab
```

The canonical devcontainer template lives in the [workstation repo](https://github.com/ssaav5-ai-labs/workstation) at `devcontainer/Dockerfile` and `devcontainer/devcontainer.json`.

## How to create a new repo devcontainer

See [howto-new-repo-devcontainer.md](howto-new-repo-devcontainer.md). In short: copy the `Dockerfile` and `devcontainer.json` from the workstation repo into the new repo's `.devcontainer/`, then `devpod up .`.

## Repos

| Repo | Location | Type |
|---|---|---|
| `handbook` | `~/code/github.com/ssaav5-ai-labs/handbook` | Knowledge repo (Windows side) |
| `workstation` | `~/code/github.com/ssaav5-ai-labs/workstation` | Code repo (DevPod workspace) |
| `career-vault` | `~/code/github.com/ssaav5/career-vault` | Private knowledge repo (Windows side) |
