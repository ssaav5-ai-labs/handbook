---
type: reference
title: LLM gateway reference
description: The one endpoint every tool calls - LiteLLM proxy with model aliases in front of OpenRouter, budgets, and key handling.
domain: ai-stack
tags: [litellm, openrouter, gateway, aliases, budget]
status: active
visibility: public
reuse: portable
created: 2026-10-22
updated: 2026-10-22
related: [index.md, ../../decisions/0008-vendor-neutral-ai-stack.md]
blog: none
---

# LLM gateway reference

One endpoint for every agent and harness: a LiteLLM proxy container in front of OpenRouter (ADR-0008). Tools never see vendor model IDs - only aliases.

## Endpoint and keys

| What | Value |
|---|---|
| URL from Windows | `http://localhost:4000` |
| URL from containers | `http://host.docker.internal:4000` (env `LLM_GATEWAY_URL`) |
| Auth | `Authorization: Bearer $LITELLM_MASTER_KEY` (env `LLM_GATEWAY_KEY` in containers) |
| Upstream key | `OPENROUTER_API_KEY`, only inside the gateway's `.env` |
| Source of truth | `...\github.com\ssaav5-ai-labs\workstation\gateway\` (compose.yaml + config.yaml) |

The master key is generated once with a random 32-byte hex value and kept in `gateway/.env` (git-ignored). Container-side env vars (`LLM_GATEWAY_URL`, `LLM_GATEWAY_KEY`) are set with `setx` on the Windows side so every new workspace inherits them.

## Aliases (chosen 2026-10-22)

| Alias | Model | Price per Mtok in/out | Role |
|---|---|---|---|
| `fast` | `z-ai/glm-5.3-flash` | $0.01 / $0.20 | Summaries, journaling, classification |
| `code` | `deepseek/deepseek-v4-pro` | $0.45 / $0.89 | Strong, cost-competitive coding; agent default |
| `reason` | `anthropic/claude-sonnet-5.5` | $2.00 / $10.00 | Frontier planning/review, sparing use |
| `local` | Ollama at `host.docker.internal:11434` | free | Offline/private work (Ollama not installed yet) |

Prices are OpenRouter list prices at time of choice; re-check before swapping.

## Budget

`max_budget: 115` USD with `budget_duration: 30d` in `config.yaml` (~100 EUR/month, matching the monthly limit on the OpenRouter key). Per-key budgets for individual harnesses can be added later via LiteLLM virtual keys.

## Operations

- Image is pinned (`litellm/litellm:v1.106.2`); update deliberately, it holds every key.
- `docker compose -f ...\workstation\gateway\compose.yaml --project-directory ...\workstation\gateway up -d` from PowerShell.
- Sanity check: `curl $LLM_GATEWAY_URL/v1/models` with the bearer key must list all four aliases.
- Small reasoning models can burn max_tokens on reasoning; give chat calls token headroom.
