---
type: adr
title: Build the AI stack on open interfaces with a self-hosted LLM gateway
description: All agents call models through a LiteLLM gateway using aliases, with OpenRouter as the default upstream; instructions, skills, tools and traces use open standards.
domain: ai-stack
tags: [llm, openrouter, litellm, portability, cost]
status: proposed
created: 2026-10-20
updated: 2026-10-20
visibility: public
reuse: portable
related: [../domains/ai-stack/index.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0008. Build the AI stack on open interfaces with a self-hosted LLM gateway

## Context
Goals: as affordable as possible for the widest audience, compatible with any LLM and any harness, no vendor lock-in.

## Options considered
1. **Each tool talks to its own vendor**: simplest start, maximum lock-in, no cost visibility.
2. **Everything talks to OpenRouter directly**: one bill, many models, but OpenRouter and its model IDs get hard-coded everywhere.
3. **Own gateway (LiteLLM) with aliases, OpenRouter upstream**: one internal endpoint; upstreams and models change in config.

## Decision
Option 3. Aliases `fast`, `code`, `reason`, `local`. Supporting standards: `AGENTS.md` for instructions, Agent Skills for reusable abilities, MCP for tools, OpenTelemetry for traces, `devcontainer.json` for environments.

## Consequences
One more service to run (a container now, on k3s later), and it holds every key, so it gets pinned versions and tight access. In return: per-key budgets, spend tracking, swap-anything flexibility.

## In a team or enterprise setting
An internal LLM gateway with budgets, audit and model aliases is the standard enterprise pattern for AI adoption; this is a working reference implementation.
