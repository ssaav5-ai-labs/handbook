---
type: reference
title: Hermes Agent reference
description: Hermes is the lab chat operator - deployed on k3s from Git, answers in Slack with read-only cluster access, diagnoses Grafana Cloud alerts, writes reviewed skills.
domain: ai-stack
tags: [hermes, agents, slack, grafana-cloud, skills, k3s, argocd]
status: draft
created: 2026-11-04
updated: 2026-11-10
visibility: public
reuse: lab-specific
blog: none
---

# Hermes Agent reference

Hermes is the lab operator assistant: you DM it in Slack, it checks the cluster with kubectl and answers. Alerts get a first diagnosis. Skills it writes are reviewed and merged into homelab-agents.

## Where skills live

- Reviewed skills: https://github.com/ssaav5-ai-labs/homelab-agents, hermes-skills/
- git-sync sidecar pulls main every 5 minutes into /git/current/hermes-skills/ (read-only)
- Hermes writes new skills into /opt/data/skills/ with write_approval on; promote by PR

## How a skill reaches Hermes

1. Write or improve a hermes-skills/name/SKILL.md in homelab-agents
2. Open a PR; CI runs check-skills.sh, shellcheck, gitleaks
3. Merge to main
4. git-sync picks it up within 5 minutes
5. Hermes reads it on next session start or skills reload

## Initial skills

- lab-status: read-only cluster health summary
- alert-triage: diagnose a Grafana alert with targeted checks

## Alerts

Two rules in the `lab` group of `platform/monitoring/rules.yaml` watch Hermes:

- `HermesDown` (warning): the hermes Deployment has no available replicas for 10m — chat and alert diagnosis are off, plain Slack alerts still work.
- `HermesBudgetLow` (info): `litellm_remaining_api_key_budget_metric{api_key_alias="hermes"} < 1` for 15m — the hermes virtual key is nearly out of budget.

## MCP servers

Hermes' managed scope honours `mcp_servers` (unlike `skills.external_dirs`, which playbook 06
found it ignores). Toolsets are skill-derived: a skill's `requires_toolsets` frontmatter
selects the servers a run gets; there is no `cron` toolset flag in v0.22.7.

| Server | URL | Tools | Trust |
|---|---|---|---|
| `crews` | `http://sre-crews.sre.svc:8000/mcp` | `investigate_alert`, `weekly_capacity_report`, `find_runbook` | `untrusted` |

- Trust `untrusted`: every interactive call asks in Slack before running; cron and
  unattended sessions deny the call outright (read-only tools only).
- Auth: `Authorization: Bearer ${CREWS_MCP_TOKEN}` (same value as the crews pod, in
  `secret.enc.yaml`).
- Fallback rule: the `alert-triage` skill (0.2.0) calls `investigate_alert` for
  `warning`/`critical`; if the tool errors, times out or reports "busy", the skill falls
  back to the playbook 06 checks and says the crew was not available.

## Resources

Right-sized from a 3-day peak working-set (peak × 1.25, rounded to 16 Mi; limit = max(2× request, peak + 128 Mi); Hermes limit floored at 1.5 Gi):

| Container | Request | Limit |
|---|---|---|
| hermes | 576 Mi | 1536 Mi (1.5 Gi) |
| git-sync | 48 Mi | 160 Mi |