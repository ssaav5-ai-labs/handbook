---
type: pattern
title: Ownership metadata from one source, stamped everywhere
description: Keep teams and products in one reviewed source and copy them onto repos, infrastructure, Kubernetes and telemetry at creation and deploy time, so every resource and signal has an owner without per-repo upkeep.
domain: ai-factory
tags: [ownership, backstage, catalog, labels, tagging, observability, finops]
status: draft
created: 2026-11-09
updated: 2026-11-09
visibility: public
reuse: portable
related: [../decisions/0035-catalog-metadata-from-one-taxonomy-in-git.md, ../decisions/0034-plain-backstage-for-the-idp.md]
---

# Ownership metadata from one source, stamped everywhere

**Problem:** a developer portal, alert routing and cost reports all need "who owns this, and what product is it part of?". If every repo, resource and dashboard keeps its own answer, the answers drift and the portal stops being trusted.

**Pattern:**

1. **One source** for the org and product model (team, sub-team, product line, product, component). Git with PR review in a small setup; an identity provider for people and teams at company scale.
2. **Use the portal's own format** for that source (Backstage `Group`, `Domain`, `System`, `Component`), so the portal reads it directly and no sync job is needed.
3. **Stamp, don't sync:** copy the keys onto everything at the moment it is created or deployed: repo templates, IaC modules (cloud tags, VM tags), GitOps manifests (namespace and workload labels).
4. **Carry it into telemetry:** the collector copies a few low-cardinality keys (owner, system) from namespaces onto metrics, logs and traces.
5. **Check it in CI or at admission:** fail when something has no owner or names one that doesn't exist.

**Payoff:** the catalog maintains itself, every alert has a route, every cost has an owner, and agents can answer "who owns this?" with one API call.

**History:** first built at a former company with a team DB and a product DB, a metadata file written into each repo, a Terraform tagging module and a namespace-labelling automation. The lab version ([ADR-0035](../decisions/0035-catalog-metadata-from-one-taxonomy-in-git.md)) replaces the databases with Git and the tagger with labels set at deploy time.
