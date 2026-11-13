---
type: pattern
title: Agent finds, human acts
description: For anything done under a person's name, let the agent gather, judge and draft from sources it may automate, and keep every outward action a deliberate, approved human step with claims traced to a source.
domain: ai-stack
tags: [agents, approvals, human-in-the-loop, privacy, job-search]
status: draft
created: 2026-11-13
updated: 2026-11-13
visibility: public
reuse: portable
related: [../decisions/0036-job-search-agent-finds-human-applies.md, ../decisions/0029-agent-writes-only-through-an-approval-gated-mcp-server.md, ../domains/ai-stack/design-job-search.md]
blog: candidate
---

# Agent finds, human acts

## Problem
Agents are good at the tedious front half of a task (reading a stream, filtering, judging fit, drafting) and risky at the back half when the back half speaks for a person: applying for a job, emailing a customer, messaging a candidate. The tempting design automates both halves and gets volume, banned accounts and statements nobody checked.

## Approach
1. **Inputs you're allowed to automate.** Use feeds meant for you (alert emails, official or public APIs, things you paste). If a platform's terms forbid bots, the agent doesn't touch the platform, and the network policy says so, not just the prompt.
2. **Rules before models.** Cheap deterministic filters first; a small model scores what's left with reasons and gaps; only the shortlist reaches the human.
3. **Draft, don't send.** The agent writes drafts where the human already works. No tool can submit, send or answer personal facts; those are placeholders.
4. **Trace every claim.** A checker step links each claim in a draft to a source line and flags the rest.
5. **One deliberate tap per write.** Read-only tools run freely; each write is "Allow once" from the human, and unattended runs can't write. A skip costs nothing.
6. **Private data stays in the private store.** Code and the pattern are public; profile, drafts and status live in a private repo, credentials are per-pod and scoped, and traces carry metadata, not content.

## Where I used it (links)
- Job search: [ADR-0036](../decisions/0036-job-search-agent-finds-human-applies.md), [design](../domains/ai-stack/design-job-search.md).
- The same approval shape for cluster actions: [ADR-0029](../decisions/0029-agent-writes-only-through-an-approval-gated-mcp-server.md).

## How it scales to a team / org
Sales outreach, recruiting sourcing, vendor and customer email all fit: the agent works the queue and drafts, a named person sends, the send is logged with who approved it. Platform terms and data protection become requirements of the platform team's agent runtime (egress allow-lists, tool catalogues without "send", retention settings on the model gateway), not guidance in each prompt.

## Pitfalls
- **Approval fatigue:** if the human approves by reflex, the gate is gone. Keep writes few and make the approval card show what will change.
- **Garbage in:** the shortlist is only as good as the feed; tuning alert searches beats tuning prompts.
- **Creeping scope:** "just let it auto-send the good ones" is the step that breaks the pattern. Make it a new decision, not a config change.
