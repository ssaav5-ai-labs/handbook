---
type: adr
title: Use zram swap with a small disk swap file on the k3s nodes, and let pods swap
description: Each k3s VM gets zram (ram/2, zstd) as its main swap and a 1 GiB swap file as a last resort, and the kubelet uses LimitedSwap so Burstable pods can swap too.
domain: k3s
tags: [k3s, memory, zram, swap, kubelet]
status: proposed
created: 2026-10-27
updated: 2026-10-27
visibility: public
reuse: portable
related: [0015-k3s-embedded-etcd-server-and-agent.md, ../domains/proxmox/reference-hardware.md, ../../playbooks/03-k3s/PLAYBOOK.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0016. Use zram swap with a small disk swap file on the k3s nodes, and let pods swap

## Context
Each k3s VM has 4.5 GB, and the hosts can't take more RAM. Backstage alone wants 2 to 4 GB later. Kubernetes used to require swap off, but swap support (`NodeSwap`) is stable in current versions, and k3s doesn't refuse to start with swap on. Promised on 2026-10-26: zram in the VMs; the Proxmox hosts already merge identical pages with KSM.

## Options considered
1. **No swap:** the classic Kubernetes advice; a memory spike ends in an OOM kill.
2. **Disk swap only:** more headroom, but slow, and wears the 256 GB SSDs that hold every VM.
3. **zram plus a small disk swap file:** compressed RAM swap (typically 2 to 3 times smaller, much faster than disk) used first; 1 GiB on disk at a lower priority catches the rest.
4. **Kubelet swap behaviour:** `NoSwap` (only the OS, containerd and k3s swap) vs `LimitedSwap` (Burstable pods may swap in proportion to their memory request; Guaranteed pods never do).

## Decision
Option 3 with `LimitedSwap`: zram at `ram / 2` with `zstd` and priority 100, `/swapfile` 1 GiB at priority 10, `vm.swappiness = 180` and `vm.page-cluster = 0` (tuned for RAM-backed swap). If the pinned k3s version can't enable `LimitedSwap`, fall back to `NoSwap` and record it.

## Consequences
- More effective memory per node at the cost of some CPU for compression, which these 2-core hosts have to spare at lab load.
- A node under memory pressure gets slow before it kills pods: watch swap use in the monitoring of playbook 05, and treat steady swapping as "needs RAM", not as normal.
- Memory requests still matter: the scheduler doesn't count swap, so requests stay honest.

## In a team or enterprise setting
Production clusters usually run without swap, or with `LimitedSwap` on dedicated node pools after testing, because predictable latency matters more than density. zram is a good default for edge, lab and developer clusters on small machines.
