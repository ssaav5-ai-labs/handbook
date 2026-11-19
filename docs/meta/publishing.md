---
type: howto
title: Publishing plan - blog and LinkedIn
description: Where posts live, how often they go out, how a journal entry becomes a post and a LinkedIn update, and the first eight weeks of posts.
domain: meta
tags: [blog, linkedin, publishing, career]
status: active
created: 2026-10-29
updated: 2026-11-19
visibility: public
reuse: portable
related: [knowledge-system.md, ../decisions/0018-blog-in-handbook-linkedin-for-reach.md, ../blog/index.md]
blog: none
---

# Publishing plan: blog and LinkedIn

**Goal:** make the lab work visible to hiring managers and consulting agencies looking for SRE and platform leadership. Every post shows real work and links to the decision and code behind it, so a reader can check it.

## Where things live

- **Blog:** this handbook, `docs/blog/posts/`, built by the MkDocs Material blog plugin and published to GitHub Pages with the rest of the site ([ADR-0018](../decisions/0018-blog-in-handbook-linkedin-for-reach.md)). Posts sit next to the ADRs, runbooks and journal they cite.
- **LinkedIn:** distribution, not storage. Each LinkedIn post is a short native post that points to the blog. The blog post is the record.
- **Custom domain:** recommended before the first post is shared on LinkedIn (see [open questions](../open-questions/index.md)). Until then, posts live at `https://ssaav5-ai-labs.github.io/handbook/blog/`.
- **Drafts:** written and reviewed in the private career-vault (Obsidian). A post enters this repo only in the PR that publishes it, because `draft: true` hides a post from the site but not from GitHub.

## Cadence

| Channel | How often | Day |
|---|---|---|
| Blog post | Every two weeks | Tuesday morning |
| LinkedIn | Every week | Tuesday morning |

On blog weeks, the LinkedIn post announces the blog post. On the weeks in between, it's a short standalone lesson (one problem, one fix, one link to an ADR or runbook), about 10 minutes of work.

Rules that keep it sustainable:

- Keep one finished post in reserve. Write a post right after the playbook run it comes from, while the journal is fresh; publish it on the schedule.
- A missed week is fine. Two in a row means the cadence is wrong: drop to monthly blog posts and keep the weekly LinkedIn lesson.
- Lab progress doesn't wait for posts, and posts don't wait for lab progress. The queue (journal entries with `blog: candidate`) is already longer than the calendar.

## From journal to post

1. **Pick.** Weekly review: entries, ADRs and playbooks with `blog: candidate` (see [knowledge system](knowledge-system.md#capture-habit)).
2. **Draft.** Copy `templates/post.md` into the career-vault, and ask the agent (`code` alias) to draft it from the journal entry and ADRs it names. Set the source's `blog:` to `drafted`.
3. **Edit.** Rewrite in your own voice. Keep the shape: problem, what I did, what broke, what I'd do as a manager, links.
4. **Check before publishing:**
    - No secrets, tokens, internal IPs or hostnames, employer or client material. Run `gitleaks detect` locally; CI runs it too.
    - Every claim has a link (ADR, journal, playbook, code). `mkdocs build --strict` checks the internal ones.
    - Prices and versions carry the date they were true.
    - The first two sentences work on their own; they are the excerpt and the LinkedIn hook.
5. **Publish.** Copy the post to `docs/blog/posts/<slug>.md`, set `draft: false` and `date:` to the publish day, and merge the PR. Set the source's `blog:` to `published`.
6. **Share.** Post the LinkedIn copy from the comment at the bottom of the post file, with one image (a diagram or screenshot) and the post URL at the end. Reply to every comment in the first day.

## LinkedIn post shape

- **Line 1, the hook:** a concrete claim or result. LinkedIn cuts the post after about two lines, so the hook has to earn the "see more" click.
- **Body:** three to five short lines or bullets. Numbers beat adjectives (8 GB, 100 EUR a month, $0.0000016).
- **The manager line:** one sentence on how this applies to a team. This is what separates an SRE-management profile from a hobby post.
- **Link, then three hashtags** (for example `#SRE #PlatformEngineering #AIagents`).
- No threads, no polls, no tagging people who weren't involved.

## Profile update (once, the week of the first post)

- **Featured:** add the handbook site and the first post.
- **Headline:** add the direction, for example "SRE / platform engineering, building AI agents for Kubernetes operations".
- **About:** two sentences on the lab and a link to the handbook.

## Next posts

Re-planned 2026-11-19. The first calendar (written 2026-10-29) slipped before anything was published, and two of its posts described a lab that has since changed (three Proxmox nodes, three k3s servers).

| Date (Tue) | Blog | LinkedIn | Source |
|---|---|---|---|
| 2026-11-24 | A vendor-neutral AI gateway: the enterprise pattern on an 8 GB laptop, and what it became three weeks later | Announce it; profile update | Playbook 00, ADR-0008, ADR-0012, ADR-0022, ADR-0025 |
| 2026-12-01 | I didn't let an AI apply for jobs for me: the agent finds, I apply | Announce it | ADR-0036, design-job-search, playbook 09 journal and run review |
| 2026-12-08 | | My scanner flagged six API keys in an agent transcript; none were real, the real leak was an address in test fixtures | Playbook 09 run review, RUNNING.md |
| 2026-12-15 | What AI-built infrastructure actually costs: measured spend, caching and provider price spread | Announce it | AI cost report, gateway reference |
| 2026-12-22 | | One hard-won lab rule (for example: never drain the node that holds local-path data) | Lessons in the k3s and platform journals |
| January | AI coordinating AI: Claude plans, OpenCode builds, every change lands as a PR | Announce it | ADR-0038, playbook 02c, after it runs end to end |

After that the calendar follows the playbooks (three-node cluster, Hermes, CrewAI crews, the Backstage IDP). Re-plan it here at each monthly review.
