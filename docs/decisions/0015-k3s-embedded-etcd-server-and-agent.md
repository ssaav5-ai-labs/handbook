---
type: adr
title: Run k3s with embedded etcd as one server and one agent, installed from pinned scripts
description: k3s-01 is the only server and starts embedded etcd from day one, k3s-02 is an agent, and both are installed by version-pinned scripts and config files in homelab-infra.
domain: k3s
tags: [k3s, kubernetes, etcd, topology, installation]
status: proposed
created: 2026-10-27
updated: 2026-10-27
visibility: public
reuse: portable
related: [0013-two-nodes-without-qdevice.md, 0016-zram-swap-on-k3s-nodes.md, ../domains/k3s/howto-add-server.md, ../../playbooks/03-k3s/PLAYBOOK.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0015. Run k3s with embedded etcd as one server and one agent, installed from pinned scripts

## Context
Two VMs of 4 vCPU and 4.5 GB, one per Proxmox node ([ADR-0013](0013-two-nodes-without-qdevice.md)). A third node may join later, and the cluster should then become three servers without being rebuilt. Kubernetes distribution: k3s, chosen for its small footprint. Still open: the datastore, how many servers, and how k3s gets installed.

## Options considered
1. **Datastore:** SQLite (k3s's single-server default, lightest) vs **embedded etcd** with `cluster-init` (a bit more memory and disk I/O, but more servers can join later, and it has built-in scheduled snapshots). k3s can migrate SQLite to etcd later, but that's one more operation to get right.
2. **Servers:** one server and one agent vs **two servers**. Two etcd members tolerate no failure (a majority of 2 is 2), so losing either node stops the API, which is worse than one server.
3. **Installation:** k3s-ansible (another tool and inventory to learn), k3sup (a convenience wrapper), cloud-init in OpenTofu (puts the cluster token in the Tofu state and ties cluster bootstrap to VM creation), or **the official installer, pinned to a tag, plus config files rendered from Git and copied over SSH**.

## Decision
Embedded etcd from day one, one server (`k3s-01` on `pve01`) and one agent (`k3s-02` on `pve02`), installed with `homelab-infra/k3s/install.sh`, which runs the k3s installer from the pinned version's tag with `/etc/rancher/k3s/config.yaml` rendered from `k3s/config/`. Bundled components stay (Traefik, ServiceLB, local-path, metrics-server). Secrets are encrypted at rest. etcd snapshots run at 02:00 with 7 kept, inside the VM disk that the 03:00 Proxmox backup copies to the other node. The cluster token lives in `homelab-infra/.env` (git-ignored) and the password manager. Topology chosen by Shawn on 2026-10-27 (ADR-0013); the details here await acceptance.

## Consequences
- While `k3s-01` is down, the API is down: nothing can be deployed or rescheduled, but pods on `k3s-02` keep running.
- Growing to three servers is a new line in `k3s/nodes.conf` and a run of the install script ([add a k3s server](../domains/k3s/howto-add-server.md)); the cluster passes through two etcd members only briefly.
- local-path volumes are tied to one node: fine for now, revisited with storage in a later playbook.
- No extra tooling: the install is readable shell plus YAML, so moving to Ansible or a GitOps-managed upgrade (system-upgrade-controller) later is easy.

## In a team or enterprise setting
Run three (or five) servers from the start behind a stable API address, keep etcd snapshots off-cluster (S3), and upgrade with system-upgrade-controller or a managed control plane. A single server is a lab trade-off, accepted only because its failure mode is known and drilled.
