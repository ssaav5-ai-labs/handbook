---
type: explanation
title: How this knowledge system works
description: Design of the handbook - repo map, folder layout, doc types, metadata schema, change handling, AI access and publishing reuse.
domain: meta
status: active
reuse: portable
visibility: public
created: 2026-10-20
updated: 2026-10-20
---

# How this knowledge system works

## Goals

1. Capture **every** setup, implementation detail and decision, from the workstation up to products built by the AI factory.
2. Absorb **changes of direction** without rewriting history.
3. Serve **humans and AI agents** equally well.
4. Keep everything **reusable in any future role**.
5. Act as the **source for blog and LinkedIn content**.
6. Make every setup **AI-first**: a few manual steps plus one short prompt, after which an agent guides you through the rest. See [AI-first playbooks](#ai-first-playbooks).

## Principles

- **Git + Markdown + YAML frontmatter is the system of record.** Editors (Obsidian, OpenKnowledge, VS Code) are views. See [ADR-0002](../decisions/0002-markdown-in-git-as-system-of-record.md).
- **One handbook, many code repos.** Knowledge lives in one place with one schema and one site. Code repos keep only a README and an `AGENTS.md` that point here.
- **One concept per file, stable paths.** This makes files easy to link, diff, and load into an agent's context.
- **Never delete decisions, supersede them.** History is the asset.
- **Public-safe by default.** No secrets, real IPs, hostnames or employer material. Use placeholders (`<lab-domain>`, `10.0.0.0/24`). Anything private goes in the personal `career-vault`.
- **Write once, reuse many times.** Journal → decision/how-to → pattern → blog → LinkedIn.

## Repo map (GitHub organization)

| Repo | Visibility | Holds |
|---|---|---|
| `handbook` | public | This knowledge base, site and blog |
| `.github` | public | Org profile, issue/PR templates, shared workflows |
| `workstation` | public | Base dev container, LLM gateway and local AI services (compose), dotfiles |
| `github-config` | public | Org settings, teams, rulesets as code |
| `homelab-infra` | public | Proxmox (VM templates, provisioning), k3s install |
| `homelab-gitops` | public | Argo CD app-of-apps: platform (Argo CD, observability, ingress, certs) and apps |
| `ai-factory` | public | Reusable agents, factory pipelines, evals |
| `<product>` | per product | One repo per dev project/product, created after the factory exists |
| `career-vault` | **private, personal account** | Raw journal, reflections, drafts, anything not public-safe |

Every code repo has the same shape: `README.md`, `AGENTS.md` (points to the handbook), `CLAUDE.md` (one line, `@AGENTS.md`), `playbooks/` (how the repo gets built, AI-first), `.agents/skills/` (harness-neutral Agent Skills, copied to harness-specific folders by `scripts/sync-skills.sh`) and `.devcontainer/` (the environment every agent and human works in). Repos are created when the work starts, not up front. Names are proposals until an ADR accepts them.

## Local folder layout

All clones live in a path that mirrors where they come from, so it scales across orgs and future employers without collisions:

```
~/code/
└── github.com/
    ├── ssaav5-ai-labs/
    │   ├── handbook/
    │   ├── workstation/
    │   ├── homelab-infra/
    │   ├── homelab-gitops/
    │   └── ai-factory/
    └── <your-username>/
        └── career-vault/
```

A future employer becomes `~/code/github.example-corp.com/...` next to it, and stays cleanly separable.

## Handbook layout

```
handbook/
├── AGENTS.md                 # rules for AI agents working in this repo
├── mkdocs.yml                # site + blog + llms.txt
├── templates/                # one template per doc type
└── docs/
    ├── index.md
    ├── meta/                 # how the system works (this file)
    ├── decisions/            # ADRs, numbered, never deleted
    ├── open-questions/       # decisions not yet made
    ├── journal/YYYY/         # dated work log, the raw capture
    ├── domains/              # living docs per area
    │   ├── workstation/
    │   ├── github/
    │   ├── proxmox/
    │   ├── k3s/
    │   ├── platform/         # Argo CD, observability, ingress, certs
    │   ├── ai-stack/         # LLM gateway, harnesses, Hermes, CrewAI, factory tooling
    │   ├── ai-factory/
    │   └── products/
    ├── patterns/             # role-agnostic, reusable know-how
    ├── inventory/            # hardware, versions, IP plan (placeholders)
    └── blog/posts/           # public write-ups
```

Each domain folder holds whatever doc types it needs: `index.md` (overview), `setup-*.md` (how-tos), `runbook-*.md`, `reference-*.md`. The doc type lives in frontmatter, so folders can be reorganized without losing meaning.

## Doc types

| `type` | Purpose | Changes how |
|---|---|---|
| `playbook` | AI-first setup for one portion of the system: manual steps, one kickoff prompt, guided steps | Updated every time a run finds a gap |
| `journal` | What happened today: commands run, problems hit, links. Fast and unpolished. | Append-only |
| `adr` | One decision: context, options, choice, consequences | Immutable once accepted; superseded by a new ADR |
| `question` | An open decision with options and what's blocking it | Closed by an ADR |
| `howto` | Reproducible steps to set something up | Updated in place |
| `runbook` | Operate or recover something | Updated in place |
| `reference` | Facts: versions, inventory, config values | Updated in place |
| `explanation` | Concepts and architecture | Updated in place |
| `pattern` | Portable lesson or framework, usable in any role | Updated in place |
| `post` | Blog article | Published, then rarely edited |

## AI-first playbooks

Setup guides are not lists of commands to copy. Each portion of the system (workstation, GitHub org, Proxmox, k3s, Argo CD, observability, the AI factory, each product) has a **playbook** in the repo that builds it: `playbooks/NN-<name>/PLAYBOOK.md`.

A playbook has three parts:

1. **Before you start 🧑**: only what a human must do (accounts, hardware, payments, signing in, clicking through a UI with no API).
2. **Kick it off**: one short prompt, e.g. *"Run the playbook `playbooks/00-workstation-knowledge`."*
3. **Steps**: each with *Why*, *Questions* (the agent asks these, with recommended defaults), *Actions*, *Verify* and *Record*.

The agent follows a single protocol, [`playbooks/RUNNING.md`](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/RUNNING.md): explain the step, ask its questions, act, verify, record decisions and journal entries, then move on. Because every step verifies before acting, playbooks are safe to re-run or resume, and each run is also a test of the documentation.

Why this works for every audience:

| Audience | What they get |
|---|---|
| You, now | Setup driven by an agent, with your decisions captured as you make them |
| AI agents | A structured, machine-followable plan with checks |
| Readers / employers | Plain-language *Why* lines and *What you'll have at the end*, readable without running anything |
| A future team | Onboarding that works the same way: clone, do the manual bits, run the prompt |

**Videos.** Each playbook can carry a `demo.tape` ([VHS](https://github.com/charmbracelet/vhs)) that regenerates a short terminal video from a script, plus an optional screen recording of a real run. Each step's *Why* line doubles as the narration script. Because tapes are code, videos are re-recorded when the playbook changes instead of going stale.

A [playbook catalog](../playbooks/index.md) in the handbook lists every playbook across repos with its dependencies.

## Frontmatter schema

Compatible with Google's Open Knowledge Format (only `type` is required there) and readable by Obsidian Bases/Dataview and MkDocs.

```yaml
---
type: adr                  # required, see table above
# playbooks add: repo: <repo>, depends_on: [<playbook paths>]
title: Use k3s for the lab cluster
description: One sentence, used by search, agents and link previews.
domain: k3s                # workstation | github | proxmox | k3s | platform | ai-stack | ai-factory | products | meta | career
tags: [kubernetes, distro]
status: accepted           # draft | proposed | accepted | active | superseded | deprecated
created: 2026-10-20
updated: 2026-10-20
visibility: public         # public | private (private never leaves career-vault)
reuse: portable            # portable | lab-specific
related: [../domains/k3s/index.md]
supersedes: []             # ADRs only
superseded_by: []          # ADRs only
blog: candidate            # none | candidate | drafted | published
---
```

## Handling changes of direction

1. A new direction starts as a `question` (if open) or goes straight to a new ADR.
2. The new ADR lists `supersedes: [NNNN]`. The old ADR gets `status: superseded` and `superseded_by`, and is otherwise untouched.
3. Living docs (howto, runbook, reference) are updated in place. Git history keeps the old version.
4. The journal entry for that day says why. This is often the best blog material, because "we changed course and here's why" is what hiring managers want to read.

## How AI agents use it

- `AGENTS.md` at the repo root tells any agent the schema, where things go and what's forbidden.
- Every code repo's `AGENTS.md` points to the handbook (a sibling folder under `~/code/github.com/ssaav5-ai-labs/`), so an agent working on `homelab-infra` reads the relevant ADRs and runbooks first.
- The site build emits `llms.txt` so remote agents can pull the whole handbook in one fetch.
- Agents write journal entries and draft ADRs and how-tos; you review via PR. Nothing reaches `main` without a PR.
- No MCP server is required. A local clone is enough. OpenKnowledge can be added later as an editor with MCP if it proves useful.

## Reuse and publishing flow

```
playbook run ──► journal entry ──► ADR / howto / runbook ──► pattern (reuse: portable)
                                   │
                                   └──► blog post (blog: candidate → published) ──► LinkedIn summary + link
```

- `reuse: portable` marks what you'd take to a new role. A `patterns/` index of those is your portable kit.
- `blog: candidate` builds a queue of post ideas automatically. Filter on it in Obsidian or with a script.
- Each post links back to the ADRs and code it came from, so readers (and recruiters) can verify the work.

## Capture habit

- **Through playbooks:** most capture happens automatically, because every playbook step records its decisions and journal notes.
- **During work:** one journal file per working session. An agent can write it from the shell history and chat.
- **When a choice is made:** an ADR, even a three-line one. Small ADRs beat missing ones.
- **When something works:** promote the journal steps into a `howto`.
- **Weekly:** review `blog: candidate` and open questions.
