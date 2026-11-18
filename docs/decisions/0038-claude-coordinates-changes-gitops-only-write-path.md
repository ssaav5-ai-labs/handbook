---
type: adr
title: Claude coordinates change work through pull requests; Argo CD is the only write path; autonomy is set per layer
description: Two loops replace the human copy-paste relay - change work runs Claude thread -> GitHub PR -> CI -> Argo CD, with bulk coding delegated to OpenCode on the gateway; runtime work stays with Hermes in Slack; each lab layer has an autonomy ceiling raised one level at a time after clean run reviews.
domain: ai-stack
tags: [agents, coordination, autonomy, gitops, claude, opencode, hermes, approvals, human-in-the-loop]
status: accepted
created: 2026-11-18
updated: 2026-11-18
visibility: public
reuse: portable
related: [0007-ai-first-playbooks.md, 0008-vendor-neutral-ai-stack.md, 0019-gitops-with-argo-cd-app-of-apps.md, 0020-secrets-in-git-with-sops-age-ksops.md, 0023-hermes-on-k3s-pod-as-sandbox.md, 0029-agent-writes-only-through-an-approval-gated-mcp-server.md, 0031-k3s-three-servers-behind-kube-vip.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0038. Claude coordinates change work through pull requests; Argo CD is the only write path; autonomy is set per layer

## Context
I use Claude (claude.ai projects) as architect, product manager, AI coordinator and reviewer. The executor is OpenCode (GLM / DeepSeek through the LiteLLM gateway) in a dev container on my 8 GB laptop. Hermes runs on k3s with read-only RBAC and Slack approvals, and was meant to grow into a Slack "AI ops" front end. It hasn't.

In practice I am the message bus. Claude writes a patch and a prompt; I download the patch, paste the prompt into OpenCode, then paste OpenCode's output back to Claude. During the job-search run (playbook 09) almost every step crossed my clipboard twice. Claude has no GitHub access, so every handbook or GitOps change travels as a patch file.

What I want: my time goes on goals, architecture and approving risky changes; AI coordinates AI for the rest. The lab has three layers (physical + Proxmox, k3s, AI factory) that don't need the same process.

Constraints: vendor-neutral and cheap (ADR-0008); existing safety lessons stay (agents never decrypt secrets or read secret-bearing files, never widen their own access, never drain k3s-03, identifiers are piped not retyped, "denied" means stop and report); the laptop has 8 GB RAM and holds the admin kubeconfig and the age key.

## Options considered
1. **Link GitHub to Claude** so project threads branch, open PRs, watch CI and squash-merge their own PRs on green (merge policy already allows it). Removes the patch shuffle; needs rulesets with no admin bypass.
2. **Argo CD as the only k3s write path.** Mostly true already; making it a rule removes ad-hoc `kubectl apply` by any agent.
3. **Claude Code (Remote Control) on the devbox VM** (ADR-0033 / playbook 02c) with scoped credentials: read-only kubeconfig, fine-grained GitHub token, no age key, no Proxmox token. Threads run their own checks; no command or output pasting.
4. **Claude Code delegates bulk coding to OpenCode headless** (`opencode run`) on the devbox, through the gateway. Output returns as the command result; the branch and CI are the real result.
5. **Folder access from Claude to the laptop's repo folders** for exports and logs. Small, immediate.
6. **Claude Code / Remote Control on the laptop.** Rejected (as on 2026-11-12): same box as the admin kubeconfig, the age key and 8 GB of RAM.
7. **Claude talks to Hermes through the Slack connector.** The connector posts as me, so Hermes would treat Claude as me, approvals included. Read-only use only until a separate bot identity exists.
8. **Hermes as the general change coordinator** (the original roadmap). Hermes runs on a GLM-class model, is safe because it is read-only, and Slack is poor for design docs and long diffs. Building the coordination plumbing on 8 GB nodes is what stalled it.
9. **OpenCode pointed at Opus as coordinator.** Neutral harness, but per-token API cost at coordinator volume, and it loses project threads, shared memory, phone access, scheduled runs and PR watching.
10. **Self-hosted orchestrator** (n8n, Temporal, a custom MCP bridge). More to build, run and secure. Rejected for now.

## Decision
Options 1-5, in three phases, with Hermes re-scoped (option 8) to runtime operations.

**Two loops.**

- *Change loop:* me -> Claude app (project threads, desktop or phone) -> Claude Code on the devbox (Remote Control) -> OpenCode for bulk coding -> LiteLLM -> OpenRouter -> cheap models. Every change lands as a GitHub PR -> CI -> Argo CD. Claude itself uses my Anthropic subscription, not the gateway.
- *Runtime loop:* Grafana Cloud alerts -> Hermes (k3s) -> crews / lab-actions, approvals in Slack. Later, Hermes may open PRs for small requests from my phone through a GitHub App that can only open PRs.

**Autonomy levels.** L1: agent proposes a PR, human merges or applies. L2: agent acts, human approves each risky action. L3: agent merges on green CI inside an allow-list, human reviews afterwards. L4: agent runs on a schedule within a budget and reports.

| Layer | Start | Ceiling | Write path | Always human |
| --- | --- | --- | --- | --- |
| Physical + Proxmox | L1 | L2 | `homelab-infra` PR; `tofu apply` by me | Hardware, BIOS, cluster joins, `tofu apply`, node rebuilds, restores |
| k3s platform | L2 | L3 | `homelab-gitops` PR -> Argo CD | `sops` edits, RBAC / NetworkPolicy widening, CRD upgrades, PVC delete or move, drains (never k3s-03) |
| AI factory + products | L2 | L4 | App repo PR -> CI -> Argo CD | Spend increases, new external services, public posts, anything sent outside the lab |

A layer moves up one level only after a clean run review (OpenCode/Claude Code export reviewed, no rule broken).

**Delegation contract.** Claude Code runs `opencode run` in a repo on the devbox with a delegation-only OpenCode config where every `ask` rule becomes `deny`, so OpenCode stops and reports instead of waiting. Claude Code's own permission rules are the outer guard. Claude reviews the diff, tests and CI before it opens or merges the PR. `opencode export` gives the full trail for run reviews.

**Phases and gates.**

1. *Git without the clipboard:* I link GitHub to Claude and install the Claude app on selected `ssaav5-ai-labs` repos, remove the admin bypass on `main` rulesets, and grant folder access to my repo folder. Claude lands parked patches as PRs. Gate: one week with no change travelling as a patch.
2. *An agent machine on the LAN:* I run playbook 02c (devbox VM). Claude adds a `claude-agent` ServiceAccount with a read-only ClusterRole in `homelab-gitops`; I place that kubeconfig and a fine-grained GitHub token on the devbox and approve Remote Control. Gate: one playbook run where I only approve, never paste.
3. *AI coordinating AI:* delegation to OpenCode, auto-merge of allow-listed PR classes (07b right-size first, then pinned image bumps), scheduled Claude reviews, optionally a separate Slack bot identity so Claude can ask Hermes directly.

**Rules that never move:** no agent decrypts secrets or reads secret-bearing files; no agent widens its own access; Claude never answers a Hermes approval prompt; identifiers are piped, never retyped; denied means stop and report.

## Consequences
- My engagement becomes goals and architecture in Claude threads, risky PR approvals on GitHub (phone works), Hermes approvals in Slack, and secrets and hardware.
- Claude becomes a dependency for coordination. The contract stays neutral (Git PRs, AGENTS.md, playbooks, CI, Argo CD), so another coordinator - Hermes, OpenCode on another model - can take over without rework. Executors stay on the gateway.
- Bulk tokens stay on cheap models; Claude work uses the subscription. Heavy Remote Control use may hit subscription limits; delegation to OpenCode is the pressure valve.
- A Claude thread with GitHub write could merge a bad change. Required checks with no bypass, Argo CD as the only write path, and allow-listed auto-merge classes bound it.
- The devbox becomes a second agent with LAN access; its read-only RBAC is the enforcing boundary, as for Hermes (ADR-0029).
- Open: whether Remote Control on the devbox needs a fresh approval per session (check in phase 2). Revisit the Slack bridge once a separate bot identity exists, and revisit Hermes' role when the gateway can run a strong local model.

## In a team or enterprise setting
This is the "humans set intent, agents do the work, Git is the contract" shape. A coordinating agent plans and reviews; cheaper worker agents execute; every change goes through PRs, CI and GitOps; and autonomy is granted per environment and raised on evidence (clean run reviews), not trust. Secrets, access changes, spend and anything that leaves the organisation stay with named humans.
