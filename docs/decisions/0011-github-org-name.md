---
type: adr
title: Name the GitHub organization ssaav5-ai-labs
description: One organization, ssaav5-ai-labs, holds all lab, platform, AI factory and product repos; the personal account holds only private personal repos.
domain: github
tags: [github, naming]
status: accepted
created: 2026-10-20
updated: 2026-10-20
visibility: public
reuse: lab-specific
related: [0004-github-free-org-public-repos.md]
supersedes: []
superseded_by: []
blog: none
---

# 0011. Name the GitHub organization ssaav5-ai-labs

## Context
Choice between separate orgs (personal, homelab, AI factory) and a single org, plus a name. `ai-labs` was already taken by another organization.

## Decision
A single organization, `ssaav5-ai-labs`, chosen by Shawn on 2026-10-20. Repos are grouped by name prefix (`homelab-*`, `ai-factory`, `product-*`) and by teams/repo properties. The personal account holds only private personal repos (`career-vault`). A product that becomes a business or gains outside collaborators can move to its own org later; GitHub keeps redirects.

## Consequences
One place for rulesets, security settings, teams, Actions secrets, runners and the planning board. One portfolio URL: `github.com/ssaav5-ai-labs`, site at `ssaav5-ai-labs.github.io/handbook`.

## In a team or enterprise setting
Mirrors the common single-org model where separation comes from teams and repository metadata, not extra orgs.
