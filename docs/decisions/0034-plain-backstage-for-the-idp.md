---
type: adr
title: Build the IDP on plain Backstage, deployed by Argo CD on k3s-03; OpenChoreo considered and not adopted
description: The AI factory's first product is an internal developer portal on upstream Backstage (own image, own small Postgres, GitHub sign-in), because OpenChoreo needs more memory than the cluster has and would replace the GitOps, secrets, observability and agent stack already built.
domain: ai-factory
tags: [backstage, idp, developer-portal, openchoreo, argo-cd, k3s, ai-factory]
status: proposed
created: 2026-11-09
updated: 2026-11-09
visibility: public
reuse: portable
related: [0008-vendor-neutral-ai-stack.md, 0019-gitops-with-argo-cd-app-of-apps.md, 0020-secrets-in-git-with-sops-age-ksops.md, 0021-grafana-cloud-for-monitoring.md, 0025-gateway-virtual-keys-with-postgres.md, 0031-k3s-three-servers-behind-kube-vip.md, 0035-catalog-metadata-from-one-taxonomy-in-git.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0034. Build the IDP on plain Backstage, deployed by Argo CD on k3s-03; OpenChoreo considered and not adopted

## Context
The AI factory's first example product is an internal developer platform (IDP) with a Backstage portal, budgeted at 2 to 4 GB (playbook 08). The cluster is three k3s servers: `k3s-01` and `k3s-02` with 4.5 GB each, and `k3s-03` with 12 GB, which already runs the stateful apps (LLM gateway, its Postgres, Hermes) ([ADR-0031](0031-k3s-three-servers-behind-kube-vip.md)). Everything is deployed by Argo CD from `homelab-gitops` ([ADR-0019](0019-gitops-with-argo-cd-app-of-apps.md)), secrets are SOPS + KSOPS ([ADR-0020](0020-secrets-in-git-with-sops-age-ksops.md)), monitoring goes to Grafana Cloud ([ADR-0021](0021-grafana-cloud-for-monitoring.md)), and the SRE agents are Hermes plus CrewAI crews behind MCP.

Before building, the question was whether to use [OpenChoreo](https://openchoreo.dev) instead of plain Backstage. Facts checked on 2026-11-09 against OpenChoreo v1.3.3:

- Apache-2.0, CNCF Sandbox since January 2026, 1.0 in March 2026, led by WSO2 (the open-source side of WSO2 Choreo).
- A full platform, not a portal: a control plane (API server, controllers, a fork of Backstage that needs an external Postgres, ThunderID identity provider, kgateway, cert-manager, External Secrets with OpenBao), a data plane (cluster agent, gateway, log collector), and optional workflow (Argo Workflows + Buildpacks) and observability (OpenSearch, Prometheus, OTel) planes. GitOps runs on Flux. Cilium is optional (only for its network "Guard" module).
- Sizing: 4 CPU / 8 GB for a single-node dev install; production wants 3 nodes of 4 CPU / 8 GB each.
- Built-in MCP servers and SRE/FinOps agents.

Sources: [quick start](https://openchoreo.dev/docs/getting-started/quick-start-guide/), [deployment topology](https://openchoreo.dev/docs/platform-engineer-guide/deployment-topology/), [production sizing](https://openchoreo.dev/docs/platform-engineer-guide/production-sizing/), [v1.1 release](https://openchoreo.dev/blog/openchoreo-v1-1-release/), [InfoQ on 1.0](https://www.infoq.com/news/2026/04/openchoreo-10/).

## Options considered
1. **OpenChoreo:** a finished IDP with golden paths, environments, builds, observability and agents out of the box. But its minimum is twice the IDP budget and more than any node but `k3s-03` has free; it brings a second GitOps engine (Flux beside Argo CD), a second secrets path (OpenBao beside SOPS), its own identity provider and gateway, and its own observability and SRE agents that overlap Grafana Cloud, Hermes and CrewAI. One main vendor, young project. And it hands over a finished IDP, which skips the work the AI factory exists to show.
2. **Plain Backstage (upstream, CNCF Incubating):** only a portal, so builds, deploys and observability stay with the tools already running. About 0.5 to 1 GB for the backend plus a small Postgres (estimate, to be measured in playbook 08). Fits Argo CD and SOPS like every other app. The most widely used IDP framework, so the skills transfer. Cost: we build and upgrade our own image and pick our own plugins.
3. **Hosted Backstage (Roadie) or a SaaS portal (Port, Cortex, OpsLevel):** no cluster cost, but paid past free tiers and a vendor lock-in that [ADR-0008](0008-vendor-neutral-ai-stack.md) rules out.

## Decision
Option 2. Plain Backstage, as follows (details settled in playbook 08):

- **Code:** a Backstage app created with `@backstage/create-app` in the `ai-factory` repo; the image built by GitHub Actions and pushed to GHCR (both free for public repos), pinned by digest in `homelab-gitops`.
- **Deploy:** an Argo CD app `backstage` (namespace `backstage`, resources finalizer per [ADR-0032](0032-argo-cd-apps-delete-resources-stateful-data-kept.md)), scheduled on `k3s-03`. Memory request about 512 Mi, limit 1 Gi, with `NODE_OPTIONS=--max-old-space-size` set below the limit.
- **Database:** its own single-replica Postgres StatefulSet in `backstage`, not the gateway's, so the two can move and fail separately. Rebuilt rather than backed up, like [ADR-0025](0025-gateway-virtual-keys-with-postgres.md): the catalog is re-read from Git, and only scaffolder task history would be lost.
- **Sign-in and secrets:** GitHub OAuth app; client secret, GitHub token and DB password as SOPS files read by KSOPS.
- **First plugins:** catalog, scaffolder, TechDocs (the handbook is already MkDocs), Kubernetes, and an Argo CD plugin. Each extra plugin is a deliberate choice, because each one costs memory and upgrade work.
- **Catalog data:** comes from one taxonomy in Git, not from hand-kept files in every repo ([ADR-0035](0035-catalog-metadata-from-one-taxonomy-in-git.md)).
- **Agents:** Hermes and the CrewAI crews read the catalog API (owners, systems, dependencies) through an MCP tool, and AI-factory products are created through scaffolder templates so they are catalogued from the first commit.

OpenChoreo stays an option for a throwaway evaluation in k3d on the devbox VM (8 GB, its exact minimum), written up as a journal entry, not as a cluster app.

## Consequences
- The IDP fits the 2 to 4 GB budget on `k3s-03` and leaves pve03's spare memory for other uses.
- One GitOps engine, one secrets path, one observability stack, one agent stack: Backstage shows them, it doesn't replace them.
- We own the Backstage image, upgrades (monthly upstream releases) and plugin choices. Plan a regular upgrade, ideally done by an agent with a PR.
- Environments, promotion and build pipelines are not provided; if the factory needs them, they are built from Argo CD and GitHub Actions and recorded in their own ADRs.
- Revisit OpenChoreo if the lab gains enough memory and the goal shifts from building an IDP to running one, or once it leaves the Sandbox.

## In a team or enterprise setting
Plain Backstage is the common choice for organisations with a platform team that can own a TypeScript app; the price is a permanent team to run it. Teams without that capacity pick a hosted Backstage or a SaaS portal. An opinionated platform such as OpenChoreo fits a greenfield organisation that wants environments, builds and a portal from one vendor, and fits badly where GitOps, secrets and observability are already standardised, because it brings its own of each.
