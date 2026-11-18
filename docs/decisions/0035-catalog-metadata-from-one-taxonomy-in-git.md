---
type: adr
title: Keep teams and products in one taxonomy in Git, in Backstage's own format, and stamp it onto repos, namespaces, VMs and telemetry
description: Ownership and product metadata (team, sub-team, product line, product, component) lives once, as Backstage Group/Domain/System/Component YAML in a small repo; templates, Argo CD, OpenTofu and Alloy copy it onto everything else, and CI checks nothing is untagged.
domain: ai-factory
tags: [backstage, catalog, ownership, metadata, labels, gitops, opentofu, observability]
status: proposed
created: 2026-11-09
updated: 2026-11-09
visibility: public
reuse: portable
related: [0034-plain-backstage-for-the-idp.md, 0019-gitops-with-argo-cd-app-of-apps.md, 0014-provision-proxmox-vms-opentofu-bpg-provider.md, 0021-grafana-cloud-for-monitoring.md, ../patterns/ownership-metadata-from-one-source.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0035. Keep teams and products in one taxonomy in Git, in Backstage's own format, and stamp it onto repos, namespaces, VMs and telemetry

## Context
A Backstage catalog decays when every repo has to keep its own `catalog-info.yaml` correct by hand. At a former company, Shawn solved this with:

- a **team DB** (teams, sub-teams) and a **product DB** (product line, product, product component) as the sources of truth;
- a module that wrote the matching metadata into each repo as a file in Git;
- a Terraform module that read that metadata and tagged every cloud resource;
- an automation that labelled Kubernetes namespaces with it, so metrics and logs carried team and product.

That cut the cost of keeping Backstage current, and gave every resource and signal an owner. The lab needs the same for the IDP ([ADR-0034](0034-plain-backstage-for-the-idp.md)), the SRE agents (who owns this alert?) and cost views later.

## Options considered
1. **Repeat the old design:** two databases, a per-repo metadata file, a Terraform module and a namespace tagger. Proven, but three copies of the same facts (DB, repo file, labels) that can drift, two databases that need an app or UI, and a custom controller to keep alive.
2. **Hand-written `catalog-info.yaml` in every repo:** Backstage's default. No central model; owners and product names drift, which is the problem Shawn solved before.
3. **One taxonomy in Git, in Backstage's entity format, copied outward by the tools already in use:** the same idea as option 1, with Git replacing both databases and the copies made at provisioning and deploy time instead of by a controller.
4. **Kyverno or Gatekeeper mutating labels at admission:** the enterprise way to enforce labels, but another controller (about 300 to 500 Mi) for a lab whose namespaces are all created from one Git repo.

## Decision
Option 3. The old design's idea (one model, stamped everywhere) is kept; the databases and the custom tagger are dropped.

- **Source of truth:** a small public repo `homelab-catalog` holding Backstage entities, reviewed by PR and validated in CI against the entity schema. Mapping: team and sub-team → `Group` (with `parent`/`children`); person → `User`; product line → `Domain`; product → `System`; product component → `Component` (or `Resource` for databases, buckets, VMs). Each entity carries the extra fields we tag with (for example `cost-center`, `tier`) as labels or annotations. A separate repo, because three consumers read it (Backstage, `homelab-gitops`, `homelab-infra`) and none of them owns it.
- **Backstage:** registers `homelab-catalog` as one location. Code repos are found by GitHub discovery; each repo's `catalog-info.yaml` is only a pointer (`spec.system`, `spec.owner`) and is written by the scaffolder template that created the repo, so a repo is catalogued and owned from its first commit. A CI check in `homelab-catalog` fails if a repo points to a system or group that doesn't exist.
- **Kubernetes:** labels are set in Git, where the namespaces are declared, not by a runtime tagger. Each app in `homelab-gitops` sets `backstage.io/kubernetes-id`, `app.kubernetes.io/part-of` (system) and `homelab/owner` (group) on its namespace and workloads with Kustomize `labels`. A CI check, like `check-app-finalizers.sh` ([ADR-0032](0032-argo-cd-apps-delete-resources-stateful-data-kept.md)), fails if a namespace lacks them or names an unknown entity.
- **Proxmox VMs (OpenTofu):** a small module in `homelab-infra` reads the taxonomy (`yamldecode` of a pinned version) and sets VM tags and descriptions, as the old Terraform module did.
- **Metrics and logs:** Alloy copies the namespace labels onto logs and onto metrics (kube-state-metrics `--metric-labels-allowlist` for namespaces), and OTel traces get them through the `k8sattributes` processor. Only low-cardinality labels (owner, system, domain) are copied, to stay inside Grafana Cloud's free-tier series budget.
- **Agents:** Hermes and the CrewAI crews resolve alert → namespace → owner group → contact (a `Group` annotation such as the Slack channel) through the Backstage catalog API.

## Consequences
- One place to change a team or product; everything else follows on the next deploy or `tofu apply`.
- No databases or controllers to run for metadata; a change is a PR with history and review.
- Labels are correct only for things deployed from Git. Something created by hand is untagged until it is moved into Git, which the CI checks don't see; acceptable in a lab where everything is GitOps.
- Backstage's entity format becomes the schema. If the portal ever changed, the YAML is still plain data that any tool can read.
- Revisit when people and teams come from an identity provider (then `Group`/`User` are ingested from it instead of written by hand), or when something outside Git starts creating namespaces (then add an admission policy).

## In a team or enterprise setting
Keep the same shape, but take people and teams from the HR system or identity provider (Entra ID, Okta, LDAP, GitHub teams) through a Backstage entity provider, since nobody should hand-edit an org chart. Keep products in Git or a product register exposed as an entity provider. Enforce the labels with an admission policy (Kyverno, Gatekeeper) for everything that isn't created through GitOps, and push the same keys into cloud tag policies and FinOps tooling (OpenCost) so ownership, alert routing and cost all join on one key.
