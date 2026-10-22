---
type: reference
title: How an AI agent runs a playbook
description: The protocol any AI agent follows when asked to run a playbook - guided, step by step, verified and recorded.
domain: meta
status: active
visibility: public
reuse: portable
created: 2026-10-20
updated: 2026-10-20
---

# How an AI agent runs a playbook

A playbook is started with one short prompt, for example:

> Run the playbook `playbooks/00-workstation-knowledge`.

From there the agent drives. The human answers questions and does the manual steps.

## Protocol

1. **Read first.** Read the playbook, `AGENTS.md`, and every ADR and open question it links. Don't act yet.
2. **Check where things stand.** For each step, run its *Verify* check first. Steps already done are reported and skipped, so a playbook can be re-run or resumed at any time.
3. **Confirm the manual prerequisites.** List any unchecked items from *Before you start* and wait until the human says they're done.
4. **For each step, in order:**
   1. **Explain** in two or three plain sentences what the step does and why it matters.
   2. **Ask** the step's *Questions*, one at a time, each with its recommended default. If an answer is already recorded in an ADR, state it and ask only whether it still holds.
   3. **Do** the step's *Actions*. Show commands before running anything destructive or anything that touches an external account.
   4. **Verify** with the step's check and show the result.
   5. **Record**: append to today's journal entry; write a `proposed` ADR for any new decision; update the how-to or reference pages the step names.
   6. **Pause** and ask whether to continue, unless the human said to run straight through.
5. **Manual steps** (marked 🧑): explain exactly what to click or do, then wait for "done" and verify.
6. **Finish** with a summary: what changed, decisions made, what's next, and `blog: candidate` if the run produced something worth posting. Open a PR with all doc changes.

## Rules

- Never commit secrets, tokens, real public IPs or hostnames. Use placeholders.
- Never push to `main`; open a PR.
- If reality differs from the playbook (a UI changed, a command fails), fix the run, then propose an edit to the playbook in the same PR. Playbooks improve every time they run.
- If a step's answer changes an accepted ADR, stop and propose a superseding ADR instead of silently diverging.
