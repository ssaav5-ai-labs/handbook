---
type: adr
title: Use a free GitHub organization with public repos
description: A free GitHub org owns all lab repos; repos are public so enterprise-grade governance features are free.
domain: github
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

# 0004. Use a free GitHub organization with public repos

## Context
Goal: practice GitHub the way an enterprise runs it, at no cost, while building a public portfolio.

## Decision
Create a Free-plan organization. Lab repos are public, which unlocks rulesets, required checks, environments, secret scanning, push protection and CodeQL for free. Required approvals are 0 because a solo owner can't approve their own PRs; automated review fills that role. Enterprise-only features (SAML SSO, audit log streaming) are practiced later on a 30-day Enterprise trial.

## Consequences
Everything public must be public-safe: SOPS-encrypted secrets, placeholders for IPs/hostnames, gitleaks in CI.

## In a team or enterprise setting
Same model with the Team or Enterprise plan, private repos and SSO.
