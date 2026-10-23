---
type: adr
title: Write setup guides as AI-first playbooks
description: Each portion of the system is set up by a playbook - manual steps, one kickoff prompt, then agent-guided steps that verify and record as they go.
domain: meta
tags: [ai-first, documentation, onboarding]
status: accepted
created: 2026-10-20
updated: 2026-10-23
visibility: public
reuse: portable
related: [../meta/knowledge-system.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0007. Write setup guides as AI-first playbooks

## Context
Classic tutorials ("1. clone, 2. run, 3. edit") go stale, hide the reasoning, and make the human do work an agent can do. The goal is setup that is driven by AI and still understandable to people.

## Options considered
1. **Command-list how-tos**: familiar, but stale fast and capture no decisions.
2. **Fully automated scripts (Ansible, shell)**: repeatable, but hide decisions and can't handle open choices.
3. **AI-first playbooks**: manual prerequisites, one kickoff prompt, then structured steps (why, questions, actions, verify, record) that an agent runs with the human.

## Decision
Option 3. Playbooks live in the repo they build (`playbooks/NN-<name>/PLAYBOOK.md`), follow `templates/playbook.md`, and run under the shared protocol in `playbooks/RUNNING.md`. Scripts and IaC are still what the agent produces and commits; playbooks are the guided path to them.

## Consequences
- Each run updates the journal and ADRs, so documentation stays current.
- Steps must be idempotent (verify before acting) so runs can resume.
- Agent-agnostic by design: plain Markdown, with a thin Claude Code skill wrapper.

## In a team or enterprise setting
The same format works for onboarding engineers and for platform self-service: "clone, do the manual bits, run the prompt." It's a strong, demonstrable AI-adoption pattern for an SRE manager.
