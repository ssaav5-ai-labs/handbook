---
type: howto
title: Give Claude Code a read-only agent user on the devbox
description: A separate `agent` Linux user on the devbox runs Claude Code (Remote Control) and headless OpenCode with its own read-only kubeconfig, fine-grained GitHub token and gateway key, and no access to the human's secrets.
domain: workstation
tags: [devbox, claude-code, opencode, remote-control, rbac, autonomy]
status: draft
created: 2026-11-25
updated: 2026-11-25
visibility: public
reuse: portable
related: [../../decisions/0038-claude-coordinates-changes-gitops-only-write-path.md, ../../decisions/0033-dev-containers-on-a-devbox-vm.md, ../../decisions/0029-agent-writes-only-through-an-approval-gated-mcp-server.md, index.md]
blog: candidate
---

# Give Claude Code a read-only agent user on the devbox

ADR-0038 phase 2. A Claude thread starts a Claude Code session on the devbox through Remote Control and checks the lab itself, so nobody pastes commands or output. The session runs as its own Linux user, `agent`, because the `debian` user holds the admin kubeconfig, the age key, the lab SSH key and the full `GH_TOKEN` (playbook 02c step 3), and the `docker` group is root-equivalent.

| | `debian` (human, dev containers) | `agent` (Claude Code, OpenCode) |
| --- | --- | --- |
| Kubeconfig | admin | `claude-agent`, read-only (`hermes-reader`), 30-day token |
| age key, lab SSH key | yes | no |
| GitHub | classic `GH_TOKEN` | fine-grained token: `ssaav5-ai-labs` repos, Contents + Pull requests read/write, Actions read, nothing else |
| Gateway | OpenCode's key | own virtual key `agent-devbox` with a budget (ADR-0025) |
| `docker` group, `sudo` | yes | no |
| Can change the cluster | `kubectl` + PRs | only by PR to `homelab-gitops`, applied by Argo CD |

## Prerequisites
- Playbook 02c is done; you can `ssh debian@192.168.86.214`.
- `homelab-gitops` PR "agent-access" is merged and Argo CD shows `agent-access` Synced.
- You're on the LAN, with your admin kubeconfig and the password manager.

## Steps
All 🧑. Run them yourself; an agent never handles these values.

1. **Make the user and lock the human's home.** On the devbox as `debian`:
   ```
   sudo adduser --disabled-password --gecos "" agent
   sudo chmod 700 /home/debian
   id agent        # must NOT list docker or sudo
   ```
2. **Read-only kubeconfig.** In your `homelab-gitops` container (admin kubeconfig):
   ```
   scripts/claude-agent-kubeconfig.sh /tmp/agent/claude-agent.kubeconfig
   ```
   Copy it to the devbox, then delete the local copy:
   ```
   sudo install -o agent -g agent -m 700 -d /home/agent/.kube
   sudo install -o agent -g agent -m 600 claude-agent.kubeconfig /home/agent/.kube/config
   ```
3. **Fine-grained GitHub token.** github.com, Settings, Developer settings, Fine-grained tokens: resource owner `ssaav5-ai-labs`, all repositories, permissions Contents read/write, Pull requests read/write, Actions read, Metadata read. Expiry 90 days. Save it in the password manager as `agent-devbox GitHub`.
4. **Gateway virtual key.** Create `agent-devbox` in the gateway (same way as the other clients, ADR-0025) with a monthly budget, aliases `fast`, `code`, `reason` only.
5. **Env file for the agent user.** `sudo -iu agent`, then `nano ~/.agent-env` with `GH_TOKEN=...`, `LLM_GATEWAY_URL=...`, `LLM_GATEWAY_KEY=...`; `chmod 600 ~/.agent-env`; add `set -a; . ~/.agent-env; set +a` to `~/.bashrc`.
6. **Tools, as `agent`.** Install Claude Code, OpenCode (same pinned version as the dev containers), `gh`, `kubectl` and `git` per their docs into the user's home or from the distro. Then `gh auth setup-git`.
7. **Clones.** `mkdir -p ~/work && cd ~/work` and clone `handbook`, `homelab-gitops`, `homelab-agents`, `homelab-infra`, `workstation`.
8. **Delegation config for OpenCode.** In each clone, generate the headless config from the repo's own `opencode.json`:
   ```
   ~/work/handbook/scripts/opencode-delegate-config.sh opencode.json > ~/.config/opencode-delegate.json
   ```
   Every `ask` rule becomes `deny`, so a headless `opencode run` stops and reports instead of waiting for a human. Claude Code runs it as `OPENCODE_CONFIG=~/.config/opencode-delegate.json opencode run "<task>"`.
9. **Remote Control.** As `agent`, in `tmux new -A -s claude`: `cd ~/work && claude remote-control`, and approve it once from the Claude app. Detach with `Ctrl+b d`; it survives the laptop sleeping.

## Working rules for the agent user
- **One worktree per task:** `git -C ~/work/<repo> worktree add ~/work/wt/<repo>-<task> -b <branch> origin/main`; remove it after the PR merges. Two tasks never share a checkout.
- **At most 2 tasks at once** on the 8 GB devbox. Raise the VM's memory in `homelab-infra` before raising this.
- Cluster changes go by PR to `homelab-gitops`; `kubectl` is for reading. Secret-bearing files and decrypts stay denied (AGENTS.md).

## Verify
As `agent`:
```
kubectl auth can-i get pods -A          # yes
kubectl auth can-i get secrets -A       # no
kubectl auth can-i create deployments -A  # no
ls /home/debian                          # Permission denied
docker ps                                # permission denied
gh auth status                           # logged in, fine-grained token
```
From a Claude thread: start a Remote Control session on the devbox and ask it to report `kubectl get nodes` and the Argo CD app list. Nothing should be pasted by you.

## Undo / rollback
`sudo deluser --remove-home agent`; revoke the fine-grained token and the `agent-devbox` gateway key; revert the `agent-access` PR (Argo CD prunes the ServiceAccount and binding). The 30-day token also expires on its own.

## Related decisions
[ADR-0038](../../decisions/0038-claude-coordinates-changes-gitops-only-write-path.md) (phase 2), [ADR-0033](../../decisions/0033-dev-containers-on-a-devbox-vm.md), [ADR-0029](../../decisions/0029-agent-writes-only-through-an-approval-gated-mcp-server.md) (RBAC as the enforcing boundary), [ADR-0025](../../decisions/0025-gateway-virtual-keys-with-postgres.md).
