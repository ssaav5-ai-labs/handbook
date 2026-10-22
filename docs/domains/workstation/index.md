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

The base devcontainer ([Dockerfile](devcontainer/Dockerfile) + [devcontainer.json](devcontainer/devcontainer.json)) bakes in every tool a code repo is likely to need:

| Tool | Version | Why |
|---|---|---|
| Python | 3.12 | Scripting, mkdocs, infrastructure tooling |
| Node.js | 24 | Agent harnesses (OpenCode), OpenKnowledge CLI |
| GitHub CLI | latest | PRs, releases, Actions from the container |
| kubectl | latest stable | k3s cluster management |
| helm | latest stable | Helm chart operations |
| OpenTofu | 1.11.0 | Infrastructure as code (open-source Terraform fork) |
| sops | 3.10.2 | Encrypted secrets in git (AGE backend) |
| age | 1.2.1 | SOPS encryption backend |
| k9s | 0.40.10 | Terminal-based cluster dashboard |

Every devcontainer also mounts the handbook at `/knowledge/handbook` (read-write, cached), so any agent in any repo can read ADRs, record journal entries, and follow playbooks without a separate clone.

The canonical devcontainer template lives in the [workstation repo](https://github.com/ssaav5-ai-labs/workstation) at `devcontainer/Dockerfile` and `devcontainer/devcontainer.json`.

## How to create a new repo devcontainer

See [howto-new-repo-devcontainer.md](howto-new-repo-devcontainer.md). In short: copy the `Dockerfile` and `devcontainer.json` from the workstation repo into the new repo's `.devcontainer/`, then `devpod up .`.

## Repos

| Repo | Location | Type |
|---|---|---|
| `handbook` | `~/code/github.com/ssaav5-ai-labs/handbook` | Knowledge repo (Windows side) |
| `workstation` | `~/code/github.com/ssaav5-ai-labs/workstation` | Code repo (DevPod workspace) |
| `career-vault` | `~/code/github.com/ssaav5/career-vault` | Private knowledge repo (Windows side) |
