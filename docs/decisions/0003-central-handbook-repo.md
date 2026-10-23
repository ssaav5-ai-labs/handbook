---
type: adr
title: Keep all knowledge in one central handbook repo
description: One handbook repo holds knowledge for every domain; code repos hold only README and AGENTS.md pointing to it.
domain: meta
tags: []
status: accepted
created: 2026-10-20
updated: 2026-10-23
visibility: public
reuse: portable
related: []
supersedes: []
superseded_by: []
blog: candidate
---

# 0003. Keep all knowledge in one central handbook repo

## Context
Knowledge spans the workstation, GitHub, Proxmox, k3s, platform apps, the AI factory and products, across several code repos. An earlier idea put docs inside the lab repo's `docs/` folder.

## Options considered
1. **Docs inside each code repo**: close to code, but split across repos with no single schema, site or decision log.
2. **One central handbook**: one schema, one site, one decision log, one blog source.

## Decision
Option 2. Each code repo keeps a README for building/running it and an `AGENTS.md` pointing agents at the handbook.

## Consequences
Doc changes and code changes land in separate PRs; link them to each other.

## In a team or enterprise setting
Larger orgs often move repo-specific runbooks back next to code and aggregate them into one site (e.g. Backstage TechDocs). Revisit if the lab grows that big.
