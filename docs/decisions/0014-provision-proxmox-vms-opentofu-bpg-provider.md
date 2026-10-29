---
type: adr
title: Provision Proxmox VMs with OpenTofu (bpg/proxmox) and a cloud-init template
description: VMs on pve01 are defined as code with OpenTofu, the bpg/proxmox provider, and cloned from a Debian 13 genericcloud template.
domain: proxmox
tags: [proxmox, opentofu, cloud-init, infrastructure-as-code]
status: proposed
created: 2026-10-23
updated: 2026-10-23
visibility: public
reuse: lab-specific
related: [../domains/proxmox/reference-proxmox.md, ../domains/proxmox/reference-hardware.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0014. Provision Proxmox VMs with OpenTofu (bpg/proxmox) and a cloud-init template

## Context
The lab has one Proxmox host (pve01, 8 GB RAM). We need to create VMs for k3s and later services. The open question "Proxmox provisioning" considered OpenTofu vs Packer vs Ansible.

## Options considered
1. **Manual VM creation in the web UI**: fast but unrepeatable; no drift detection or code review.
2. **Packer for images + Ansible for configuration**: two tools for what is currently one simple VM; adds complexity.
3. **OpenTofu (bpg/proxmox) + cloud-init template**: one tool, one template, VMs defined as code in git.

## Decision
Option 3. Create a Debian 13 genericcloud template (`debian13-cloud`, VM 9000) on pve01, then clone VMs from it with `proxmox_virtual_environment_vm` resources in OpenTofu (bpg/proxmox v0.118.0). Cloud-init injects SSH keys, network config, and runs `package_upgrade` on first boot.

An API token (`tofu@pve!homelab-infra`) with a least-privilege role (`TofuProvisioner`) authenticates the provider — never root.

## Consequences
- VM changes go through PRs with `tofu plan` diffs.
- Rebuilding a VM is one `tofu apply` (plus a backup restore if data is needed).
- A second node or additional VMs use the same template and pattern — no new tooling needed.
- State is local and git-ignored for now (single user, single host). Remote state is an open question for when the lab grows.
- Will need Packer or Ansible later if VM configuration grows beyond what cloud-init + cloud-init custom config can express in a maintainable way.

## In a team or enterprise setting
A team would add a remote state backend (S3, Terraform Cloud, or GCS) and split state across workspaces. The template could be built with Packer in CI and promoted across environments.