---
type: adr
title: Let agents change the cluster only through a separate, approval-gated MCP server that only Hermes can reach
description: Crews and Hermes stay read-only; the lab's write actions live in a small lab-actions MCP server with its own narrow ServiceAccount, reachable only from Hermes, which marks it untrusted so every call needs a human "Allow once" in Slack and unattended sessions can't call it. The first action restarts a Deployment's pods in allow-listed namespaces.
domain: ai-stack
tags: [mcp, hermes, approvals, rbac, security, agents, argocd]
status: accepted
created: 2026-11-04
updated: 2026-11-13
visibility: public
reuse: portable
related: [0019-gitops-with-argo-cd-app-of-apps.md, 0023-hermes-on-k3s-pod-as-sandbox.md, 0027-crewai-crews-as-mcp-tools.md, 0028-agent-read-access-through-upstream-mcp-sidecars.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0029. Let agents change the cluster only through a separate, approval-gated MCP server that only Hermes can reach

## Context
ADR-0023 kept Hermes read-only and said that write access, if it came, should be narrow, behind approvals, and its own ADR. The crews (ADR-0027) are read-only too. Some fixes are routine and safe to do on request (restarting a wedged gateway or collector), and making the human type `kubectl` from a laptop for them defeats the point of a phone-first operator.

Hermes (v0.22.x) supports a per-MCP-server `trust: untrusted`: every call to a tool not annotated read-only goes through its approval surface (Slack buttons: Allow once, Session, Always, Deny); sessions where nobody can answer (cron, alert-driven) refuse. "Always" writes to `command_allowlist`, which the lab pins empty in the managed config.

The cluster is reconciled by Argo CD with self-heal (ADR-0019): any change to a managed object's spec is reverted.

## Options considered
1. **Give Hermes' ServiceAccount write verbs**: simplest, but every shell command Hermes runs could use them, and approval depends on its command patterns.
2. **Writes only by PR**: the GitOps ideal, but too slow for "restart the gateway now", and a restart isn't a change of desired state.
3. **A separate MCP server with one narrow action per tool, its own ServiceAccount, reachable only from Hermes, marked untrusted**: the approval is enforced by Hermes' MCP layer for every call; the permission is enforced by Kubernetes for what the tool can touch.

## Decision
Option 3. `lab-actions` runs in namespace `sre`, from the crews' image with its own entry point (it doesn't load CrewAI):
- **One tool to start:** `restart_workload(namespace, deployment, reason)`, which deletes the Deployment's pods one at a time and waits for each replacement. It doesn't patch the Deployment, so Argo CD sees no drift (a rollout restart would change the pod template and self-heal would revert it, restarting the pods again).
- **Allow-list** of namespaces in the server and in RBAC: Roles only in `llm-gateway` and `monitoring` (`get` Deployments, `list` and `delete` pods). Never `hermes`, `sre`, `argocd`, `kube-system`.
- **Reach:** NetworkPolicy ingress only from Hermes, bearer token; egress only DNS and the API server.
- **Approval:** Hermes' managed config lists the server with `trust: untrusted`; the managed empty `command_allowlist` means "Always" can't persist; cron and unattended sessions deny. Crews can't reach it.
- **Each new action** is a new tool with the narrowest Role, tests, and a PR in both repos (how-to in the handbook); an action that changes desired state (scaling, config) goes through a PR instead.

## Consequences
- The lab gets a phone-first fix for the commonest problem, with a human decision on every call and an audit line in two logs (Hermes and `lab-actions`).
- A prompt injection in an alert can't trigger a write: the alert path is unattended, and the crews have no route to the server.
- Approval fatigue is the real risk: if "Allow once" becomes reflex, the guard is gone. Keep actions few, and show the reason and the arguments.
- One more small pod (about 48 Mi) and a second token in Hermes' Secret.
- RBAC on Hermes' ServiceAccount is the enforcing boundary for shell actions, and it must stay read-only. Hermes' approval prompt only keys off a fixed, code-shipped set of dangerous-command patterns that does not include `kubectl` — a shell `kubectl rollout restart` ran with no approval prompt and was stopped only because the SA cannot patch. So `approvals.deny` blocks the `kubectl` write verbs Hermes must never run, and the read-only SA is the backstop for any pattern that slips through.

## In a team or enterprise setting
Separate the agent that reasons from the identity that acts: actions as narrow, typed tools behind a policy point (approval, change window, ticket), each with its own least-privilege identity, and desired-state changes through Git. This is the same shape as a bot-driven ChatOps runbook, with an LLM choosing which runbook to propose.
