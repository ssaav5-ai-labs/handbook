---
type: adr
title: Keep a private career vault in a personal repo
description: Private reflections, raw notes and drafts live in a private repo under the personal GitHub account, edited in Obsidian.
domain: meta
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

# 0005. Keep a private career vault in a personal repo

## Context
Some knowledge isn't public-safe (raw reflections, salary/career notes, employer material) and must stay personally owned across jobs.

## Decision
A private `career-vault` repo under the personal account (not the org), using the same frontmatter schema. Content is promoted to the public handbook by copying a sanitized version via PR.

## Consequences
Two places to look; the `visibility` field and the promotion step keep them distinct.
