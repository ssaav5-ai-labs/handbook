---
type: journal
title: Choosing a model per task and reviewing the gateway aliases
description: Why OpenCode only shows an alias, and a proposal for picking the alias per playbook step and reviewing alias targets monthly.
domain: ai-stack
tags: [llm-gateway, aliases, opencode, model-selection]
status: active
created: 2026-11-19
updated: 2026-11-19
visibility: public
reuse: lab-specific
blog: none
---

# 2026-11-19: Choosing a model per task and reviewing the gateway aliases

## Goal
Find out which model OpenCode really uses, and make sure each kind of work gets a suitable model.

## What I did
- OpenCode's status bar shows `Build · code · LLM gateway`: agent, gateway alias, provider name. OpenCode never sees the model behind the alias. The handbook maps `code` to `deepseek/deepseek-v4-pro`; the live mapping is in homelab-gitops, and `$LLM_GATEWAY_URL/v1/model/info` (with a key allowed to read it) or a Langfuse trace shows the real model.
- Asked Claude how to make sure Claude-directed OpenCode work uses the best model per task, and whether the models behind the aliases should be reviewed as the market changes.

## What broke and how I fixed it
Nothing broke.

## Decisions made (link ADRs)
- [ADR-0039](../../decisions/0039-model-per-task-and-scheduled-alias-reviews.md) (proposed): pick the alias per playbook step before the session starts, never switch mid-session (prompt cache), escalate to `reason` after two failed verifies, and review alias targets monthly with our own replay eval.

## Next
- Accept or amend ADR-0039.
- Add `Model:` lines to the active playbooks as they are next run.
- Build the first replay set from scrubbed exports and set up the monthly review task.
