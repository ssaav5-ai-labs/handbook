---
type: playbook
title: <Set up X>
description: <One sentence: what exists when this playbook is done>
domain: <domain>
tags: []
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
visibility: public
reuse: portable
repo: <repo this playbook builds>
depends_on: []            # other playbooks that must be finished first
related: []               # ADRs, open questions, how-tos
blog: candidate
---

# <Set up X>

## What you'll have at the end
<Plain-language outcome, 2-3 sentences. A diagram if it helps.>

## Before you start 🧑
Things only a human can do (accounts, hardware, payments, approvals, signing in).

- [ ] <Manual prerequisite>

## Kick it off
Paste this into your AI agent from the repo folder:

> Run the playbook `playbooks/NN-<name>`.

## Steps

### 1. <Step name>
**Why:** <one sentence>
**Questions:** <what the agent asks you, each with a recommended default>
**Actions:** <what the agent does>
**Verify:** <a command or check that proves the step is done>
**Record:** <docs/ADRs this step creates or updates>

### 2. <Manual step name> 🧑
**Why:** ...
**You do:** <exact clicks/actions>
**Verify:** ...

## When it's done
- Docs updated: <links>
- Next playbook: <link>

## Video
<Optional: link to the recording of a run, and the `demo.tape` used to regenerate it.>
