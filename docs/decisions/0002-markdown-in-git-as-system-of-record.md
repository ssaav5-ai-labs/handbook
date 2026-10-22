---
type: adr
title: Use Markdown with YAML frontmatter in Git as the knowledge system of record
description: Knowledge is plain Markdown files with a shared frontmatter schema, versioned in Git; editors are interchangeable.
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

# 0002. Use Markdown with YAML frontmatter in Git as the knowledge system of record

## Context
Needs: portable across jobs, readable by AI agents, team-ready, no lock-in, usable as a blog source.

## Options considered
1. **Obsidian vault only**: great personal editor, weak for teams.
2. **Outline (self-hosted wiki)**: strong team UX and built-in MCP, but content lives in Postgres, not Git.
3. **OpenKnowledge**: AI-native Markdown editor with MCP; young project, Git-based sharing.
4. **Markdown + frontmatter in Git, rendered with MkDocs Material**: docs-as-code.

## Decision
Option 4 as the store. Obsidian for personal editing, OpenKnowledge optional as an AI-assisted editor, Outline deferred (possibly deployed on k3s later as a team-wiki demo). Frontmatter follows the Open Knowledge Format shape (required `type`).

## Consequences
No real-time co-editing; changes go through PRs. Agents can read and write directly from a clone. Material for MkDocs enters end of maintenance on Nov 5, 2026 and MkDocs 2.0 is incompatible, so MkDocs is pinned to 1.6.1; because content is plain Markdown, switching generators (e.g. to Zensical) only touches config.

## In a team or enterprise setting
Docs-as-code with PR review, CODEOWNERS and CI checks is a common SRE/platform pattern.
