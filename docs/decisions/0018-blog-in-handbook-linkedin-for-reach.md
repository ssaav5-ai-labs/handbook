---
type: adr
title: Host the blog in the handbook on GitHub Pages; use LinkedIn for reach
description: Posts live in the handbook's MkDocs Material blog next to the ADRs and code they cite; LinkedIn gets short native posts that link back.
domain: meta
tags: [blog, linkedin, github-pages, mkdocs]
status: proposed
created: 2026-10-29
updated: 2026-11-19
visibility: public
reuse: portable
related: [../meta/publishing.md, 0002-markdown-in-git-as-system-of-record.md, 0003-central-handbook-repo.md]
supersedes: []
superseded_by: []
blog: none
---

# 0018. Host the blog in the handbook on GitHub Pages; use LinkedIn for reach

## Context
The lab work should be visible to employers and consulting agencies. Posts need to be cheap to write (they come from journal entries and ADRs), easy to verify (readers can click through to the decision and code), and owned by me, not a platform. The handbook already builds an MkDocs Material site on GitHub Pages with the blog plugin enabled.

## Options considered
1. **Blog plugin in the handbook, GitHub Pages:** already built and deployed; posts link to ADRs with relative links that the strict build checks; free; one repo and one review flow. The URL (`ssaav5-ai-labs.github.io/handbook/blog/`) is long, and the look is a docs site rather than a personal site.
2. **Separate site repo (Hugo, Astro or another Material site) on GitHub Pages:** a cleaner personal brand, but a second build, a second theme to maintain, and cross-repo links that nothing checks.
3. **Hosted platform (Hashnode, dev.to, Medium, Substack):** built-in audience and comments, but the platform owns the URLs and the format, and posts drift away from the evidence they cite.
4. **LinkedIn articles only:** most reach with recruiters, but no ownership, weak code formatting, and nothing outside LinkedIn.

## Decision
Option 1. The blog lives in `docs/blog/posts/` in the handbook. LinkedIn carries short native posts that link to each blog post; it is distribution, not the record. Post URLs use the slug only (`post_url_format: "{slug}"`) so they never encode a date or a folder that might change. The cadence and workflow are in the [publishing plan](../meta/publishing.md).

## Consequences
- No new infrastructure. Writing a post is a PR like any other handbook change, and the gitleaks and strict-build checks apply to it.
- Posts depend on the site generator. Material for MkDocs 9.8.x says it gets only critical fixes until its end of life on 2027-05-05; `mkdocs-material` is now pinned, and the Zensical migration has to keep the blog URLs working.
- Links shared on LinkedIn are permanent. A custom domain pointed at GitHub Pages (free on Pages, about the price of a domain per year) would keep them working through any later move of host or generator. Decide before the first post is shared on LinkedIn.
- A separate personal site stays possible later: with a custom domain, the blog can move without breaking links.

## In a team or enterprise setting
The same split works for an engineering blog: write in the repo next to the design docs, review by PR, publish from CI, and treat social channels as distribution. It keeps posts honest because they cite reviewed decisions.
