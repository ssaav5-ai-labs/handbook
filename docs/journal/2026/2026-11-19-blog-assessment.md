---
type: journal
title: Blog assessment and a restart of the publishing plan
description: Nothing was published 16 days after the planned first post; the blog plumbing was never merged, so this adds ADR-0018, the publishing plan and a working blog config, and re-plans the calendar.
domain: meta
tags: [blog, linkedin, publishing, mkdocs]
status: active
created: 2026-11-19
updated: 2026-11-19
visibility: public
reuse: lab-specific
related: [../../decisions/0018-blog-in-handbook-linkedin-for-reach.md, ../../meta/publishing.md]
blog: none
---

# 2026-11-19: Blog assessment and a restart of the publishing plan

## Goal
Find out why no post has gone out since the plan of 2026-10-29, and get the pipeline ready for the first post.

## What I did
- Reviewed the three post drafts against the handbook: links resolve and no private data, but the gateway post's "what's next" (tracing, virtual keys, gateway on the cluster) has since shipped, and the job-search post can now report real numbers.
- Ran `mkdocs build --strict` with the drafts as published posts. It failed on `Couldn't find author 'shawn'`; with `docs/blog/.authors.yml` both posts build clean.
- Added ADR-0018 (proposed), the publishing plan with a new calendar, the author file, slug-only post URLs, a pinned `mkdocs-material`, and the post template with the LinkedIn copy kept in a comment.

## What broke and how I fixed it
- The blog-plan change from 2026-10-29 stayed a local patch and never reached `main`, so every later post waited on plumbing. It is now a PR of its own, without any post in it.
- Default blog URLs contain the post date, so re-dating a post would change its link. `post_url_format: "{slug}"` fixes that before any link is shared.

## Decisions made (link ADRs)
- [ADR-0018](../../decisions/0018-blog-in-handbook-linkedin-for-reach.md) proposed (blog in the handbook, LinkedIn for reach).
- Drafts stay in the private career-vault until the PR that publishes them.

## Next
- Decide on a custom domain before the first post is shared.
- Publish the refreshed gateway post on 2026-11-24 and the job-search post on 2026-12-01 ([publishing plan](../../meta/publishing.md)).
