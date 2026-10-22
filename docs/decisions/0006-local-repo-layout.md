---
type: adr
title: Clone repos under ~/code/<host>/<owner>/<repo>
description: Local clones mirror their remote location, so repos from any org or future employer never collide.
domain: workstation
tags: []
status: proposed
created: 2026-10-20
updated: 2026-10-20
visibility: public
reuse: portable
related: []
supersedes: []
superseded_by: []
blog: candidate
---

# 0006. Clone repos under ~/code/<host>/<owner>/<repo>

## Context
Repos will come from the lab org, the personal account and future employers.

## Decision
Use `~/code/<host>/<owner>/<repo>` (e.g. `~/code/github.com/ssaav5-ai-labs/handbook`). Tools such as `ghq` can automate this.

On the Windows laptop (Docker Desktop + DevPod):
- **Knowledge repos** (`handbook`, `career-vault`) are cloned on the Windows side at `$env:USERPROFILE\code\github.com\...`, so Obsidian and OpenKnowledge open them natively.
- **Code repos** run as **DevPod workspaces** created from their git URLs. Source lives in the container's volume, which avoids slow Windows-to-container file sharing.
- Every devcontainer mounts the handbook at `/knowledge/handbook` (read-write), so an agent in any repo can read ADRs and record journal entries.

## Consequences
Agents can find the handbook at a predictable path (`/knowledge/handbook` inside containers). Employer work stays physically separate from personal work.
