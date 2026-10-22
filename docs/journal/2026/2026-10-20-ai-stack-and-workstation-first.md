---
type: journal
title: Vendor-neutral AI stack and workstation-first ordering
description: Chose an LLM gateway with aliases over OpenRouter, Hermes for local automation, and moved workstation + knowledge capture to playbook 00.
domain: ai-stack
tags: [openrouter, litellm, hermes, crewai, langfuse, devpod]
status: active
created: 2026-10-20
updated: 2026-10-20
visibility: public
reuse: portable
blog: candidate
---

# 2026-10-20: AI stack and workstation first

## What I did
- Set constraints: cheapest workable models via OpenRouter, any LLM and any harness, no lock-in; containerized dev on Windows with Docker Desktop + DevPod.
- Checked Hermes Agent (MIT, OpenRouter, MCP, Agent Skills, cron), LangSmith licensing (proprietary, enterprise-only self-host) and Langfuse (MIT core).
- Reordered playbooks so workstation and knowledge capture come first.

## Decisions made
ADR-0008, ADR-0009 (proposed); ADR-0006 amended for the Windows layout; ADR-0010 Langfuse for tracing and evals (accepted).

## Next
Run playbook 00.
