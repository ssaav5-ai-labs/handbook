---
type: adr
title: Record decisions as ADRs
description: Every meaningful choice gets a short, numbered, immutable decision record.
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

# 0001. Record decisions as ADRs

## Context
The lab will change direction many times. Without a record, the reasoning behind each choice is lost, and that reasoning is the most valuable thing to show employers and reuse later.

## Decision
Use lightweight ADRs (this template) in `docs/decisions/`. Accepted ADRs are never edited; a new ADR supersedes them. Undecided choices live in `docs/open-questions/`.

## Consequences
Small overhead per decision. Gives a complete, linkable decision history for humans, agents and blog posts.

## In a team or enterprise setting
ADRs in the repo, reviewed via PR, are a standard engineering-management practice and scale to teams without new tooling.
