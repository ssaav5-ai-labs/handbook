---
type: journal
title: Playbook 03 written - k3s on two nodes, with zram
description: Wrote the k3s playbook for the two-node lab - embedded etcd server plus agent, zram, pinned install scripts, kubeconfig on Windows - and the how-to for growing to three servers.
domain: k3s
tags: [k3s, etcd, zram, playbook]
status: active
created: 2026-10-27
updated: 2026-10-27
visibility: public
reuse: lab-specific
related: [../../../playbooks/03-k3s/PLAYBOOK.md, ../../decisions/0015-k3s-embedded-etcd-server-and-agent.md, ../../decisions/0016-zram-swap-on-k3s-nodes.md, ../../decisions/0017-kubeconfig-on-windows-mounted-into-containers.md]
blog: candidate
---

# 2026-10-27: Playbook 03 written - k3s on two nodes, with zram

## Goal
Have playbook 03 ready while playbook 02 finishes on `pve01` and `pve02`, so k3s can go on the VMs as soon as they exist.

## What I did
- Wrote [playbook 03](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/03-k3s/PLAYBOOK.md): checks the VMs, adds zram and a safety-net swap file, pins k3s, installs the server on `k3s-01` and the agent on `k3s-02` from scripts in `homelab-infra/k3s/`, fetches the kubeconfig, runs a cross-node smoke test, and drills etcd snapshots and node reboots.
- Built the hook for a third node into the scripts from the start: `k3s/nodes.conf` lists nodes and roles, and every `server` after the first joins etcd. The steps are in [add a k3s server](../../domains/k3s/howto-add-server.md).
- Solved two workstation papercuts in the same run: the kubeconfig and the SSH key were lost on every container rebuild.

## What broke and how I fixed it
Not run yet. Things to check on the first run: whether the Debian cloud kernel ships the `zram` module, and where the pinned k3s reads kubelet drop-ins for `LimitedSwap`.

## Decisions made (link ADRs)
- [ADR-0015](../../decisions/0015-k3s-embedded-etcd-server-and-agent.md) (proposed): embedded etcd from day one, one server and one agent, pinned installer plus config from Git; bundled components kept.
- [ADR-0016](../../decisions/0016-zram-swap-on-k3s-nodes.md) (proposed): zram (`ram / 2`, `zstd`) plus a 1 GiB swap file, `LimitedSwap` for pods.
- [ADR-0017](../../decisions/0017-kubeconfig-on-windows-mounted-into-containers.md) (proposed): kubeconfig in `%USERPROFILE%\.kube` mounted into containers, SSH key in a Docker volume.
- ADR-0014 stays reserved for the provisioning decision recorded during the playbook 02 run.

## Next
- Finish playbook 02, then run playbook 03 and accept or change the three ADRs.
- Playbook 04: Argo CD, and the secrets decision (SOPS + age).
