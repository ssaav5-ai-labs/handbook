---
type: adr
title: Use Hermes Agent for local AI automations, sandboxed
description: Hermes Agent runs local agentic automations through the LLM gateway, in a container, with reviewed skills and scoped credentials.
domain: ai-stack
tags: [hermes, automation, agents, security]
status: proposed
created: 2026-10-20
updated: 2026-10-20
visibility: public
reuse: portable
related: [../domains/ai-stack/index.md, 0008-vendor-neutral-ai-stack.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0009. Use Hermes Agent for local AI automations, sandboxed

## Context
Need an always-on agent for local automations and workflows (scheduled checks, triage, summaries, chat notifications) that fits ADR-0008.

## Options considered
1. **Hermes Agent**: MIT, any provider/custom endpoint, MCP, Agent Skills, cron, chat gateways, Docker terminal backend, Windows support. Young and permission-hungry.
2. **n8n**: visual deterministic workflows with AI nodes; source-available license rather than OSI open source.
3. **Plain scripts + cron/GitHub Actions**: fully deterministic, no judgment.

## Decision
Hermes for agentic automations; plain cron/Actions for deterministic jobs. Guardrails: containerized, Docker terminal backend, command approval on, scoped read-only credentials first, model calls via the gateway, skills directory in git with PR review, versions pinned.

## Consequences
Learned skills become reviewable assets. Memory (SQLite) is treated as a cache; durable knowledge is promoted to the handbook.

## In a team or enterprise setting
Same guardrail pattern (sandbox, least privilege, reviewed skills, gateway budgets) applies to any autonomous agent rollout.
