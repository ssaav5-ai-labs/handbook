---
type: playbook
title: Run the cluster from Git with Argo CD, secrets encrypted with SOPS and age
description: Creates the homelab-gitops repo, installs a slim Argo CD with Helm, hands Argo CD its own management (app-of-apps), and proves encrypted secrets work end to end with SOPS, age and KSOPS.
domain: platform
tags: [argocd, gitops, helm, app-of-apps, sops, age, ksops, secrets]
status: draft
created: 2026-10-29
updated: 2026-10-29
visibility: public
reuse: portable
repo: homelab-gitops
depends_on: [../03-k3s]
related:
  - ../../docs/decisions/0015-k3s-embedded-etcd-server-and-agent.md
  - ../../docs/decisions/0017-kubeconfig-on-windows-mounted-into-containers.md
  - ../../docs/decisions/0019-gitops-with-argo-cd-app-of-apps.md
  - ../../docs/decisions/0020-secrets-in-git-with-sops-age-ksops.md
  - ../../docs/domains/k3s/reference-k3s.md
  - ../../docs/open-questions/index.md
blog: candidate
---

# Run the cluster from Git with Argo CD, secrets encrypted with SOPS and age

## What you'll have at the end
A public `homelab-gitops` repo that is the source of truth for everything running on the k3s cluster from now on. Argo CD runs in the `argocd` namespace, slimmed down to about half a gigabyte of RAM, with its web UI behind the k3s Traefik ingress. Helm installs it once; after that Argo CD manages itself from Git (app-of-apps, [ADR-0019](../../docs/decisions/0019-gitops-with-argo-cd-app-of-apps.md)), so an upgrade is a pull request. Secrets live in the same repo, encrypted with SOPS and an age key, and Argo CD decrypts them while it renders manifests (KSOPS, [ADR-0020](../../docs/decisions/0020-secrets-in-git-with-sops-age-ksops.md)). A harmless canary secret proves the whole path works, and two drills prove Git wins over hand edits.

```
GitHub: ssaav5-ai-labs/homelab-gitops (main, PRs + ci)
        │  polls every 3 min
        ▼
argocd namespace (k3s)
  root ──► apps/*.yaml ──► argocd        (Argo CD manages itself: chart + values from Git)
                     └──► sops-canary   (KSOPS decrypts *.enc.yaml with the age key)
  repo-server + ksops ◄── Secret sops-age (age private key, created once by bootstrap)

laptop: dev container ── kubectl, helm, sops, age (key from %USERPROFILE%\.sops-age)
browser ── https://argocd.<k3s-01-ip>.nip.io  (Traefik, self-signed cert)
```

What stays out of Argo CD for now: k3s's bundled Traefik, ServiceLB, local-path and metrics-server. k3s installs and upgrades them itself; when one needs settings, a `HelmChartConfig` for it goes into this repo.

## Before you start 🧑
- [ ] Playbook 03 is done: in the `homelab-infra` container, `kubectl get nodes` shows `k3s-01` and `k3s-02` `Ready`.
- [ ] The handbook on Windows is on `main` and up to date (it includes this playbook and the `opencode.json` that blocks reading the age key).
- [ ] A password manager entry is ready for the **age private key** (step 3) and the **Argo CD admin password** (step 5). Without the age key, nobody can decrypt the secrets in Git, including you.
- [ ] Only one dev container runs at a time (8 GB laptop). If the `homelab-infra` or `handbook` container is up and **no agent is working in it**, stop it: `devpod stop homelab-infra` / `devpod stop handbook`.
- [ ] Create the repo folder, the age key folder and the dev container, in **PowerShell**:
```powershell
$r = "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\homelab-gitops"
New-Item -ItemType Directory -Force "$r\.devcontainer", "$env:USERPROFILE\.sops-age" | Out-Null
Copy-Item "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\workstation\devcontainer\*" "$r\.devcontainer\"
Copy-Item "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\handbook\opencode.json" $r
$f = "$r\.devcontainer\devcontainer.json"
$j = Get-Content $f -Raw | ConvertFrom-Json
$j.mounts += 'source=${localEnv:USERPROFILE}\.sops-age,target=/home/vscode/.sops-age,type=bind'
$j.containerEnv | Add-Member -Force -NotePropertyName SOPS_AGE_KEY_FILE -NotePropertyValue '/home/vscode/.sops-age/keys.txt'
$j | ConvertTo-Json -Depth 10 | Set-Content $f
devpod up $r --ide none
$c = docker ps --format "{{.ID}} {{.Image}}" | Select-String "vsc-homelab-gitops" | ForEach-Object { $_.Line.Split(" ")[0] } | Select-Object -First 1
docker exec -it -u vscode -w /workspaces/homelab-gitops $c bash
```
  The single quotes matter: PowerShell must not expand `${localEnv:USERPROFILE}`, DevPod does. The key folder is a Windows folder like `.kube` ([ADR-0017](../../docs/decisions/0017-kubeconfig-on-windows-mounted-into-containers.md)), so the key survives container rebuilds; `sops` and `age` don't check file permissions, so the bind mount is fine.
- [ ] In the container, one at a time: `gh auth login -h github.com -s repo,workflow` (enter the code on github.com, then click the final green **Authorize**), then `git config --global --add safe.directory /knowledge/handbook`, then `kubectl get nodes` (both `Ready`, through the mounted kubeconfig).

## Kick it off
In the container's terminal:
```bash
opencode
```
> Read `/knowledge/handbook/playbooks/RUNNING.md`, then run the playbook `/knowledge/handbook/playbooks/04-argocd`.

If you're resuming an earlier run, say so: the agent checks each step's Verify first and skips what's done.

**Keep a second terminal for yourself.** Some steps ask you to look at a secret, which the agent must never see. Open a second PowerShell window and run `docker exec -it -u vscode -w /workspaces/homelab-gitops $c bash` (in a new window, set `$c` again with the `docker ps` line above). That shell is yours, not the agent's.

## Steps

### 1. Create the homelab-gitops repo
**Why:** Everything the cluster runs is declared in one repo, separate from the infrastructure that builds the cluster (`homelab-infra`). Argo CD reads it anonymously, so it's public, and nothing in it may be readable unless it's meant to be public.
**Actions:** On a new handbook branch, open today's journal entry. In `homelab-gitops`: `git init -b main` (identity from playbook 00), then `README.md` (what the repo is, the layout below, a link to the handbook), `AGENTS.md` (pointing to the handbook and `RUNNING.md`, like `homelab-infra`), and a `.gitignore` with `.env`, `.runs/`, `keys.txt`, `*.agekey` and `*.dec.yaml`. Create `ssaav5-ai-labs/homelab-gitops` (public) with `gh repo create --source . --push`. The layout this playbook builds:
```
bootstrap/   versions.env, argocd/values.yaml, install.sh, root.yaml, project.yaml
apps/        one Argo CD Application per file (the root app watches this folder)
platform/    what the apps deploy: sops-canary/ now, monitoring in playbook 05
scripts/     checks used by CI
.sops.yaml   which files SOPS encrypts, for which age key
```
**Verify:** `gh repo view ssaav5-ai-labs/homelab-gitops --json visibility` says `PUBLIC`; `git check-ignore keys.txt .env` prints both; `kubectl get nodes` shows both nodes `Ready`; `echo $SOPS_AGE_KEY_FILE` prints `/home/vscode/.sops-age/keys.txt` (the path only, no key exists yet).
**Record:** Journal: repo created.

### 2. Pin Argo CD and write its values
**Why:** A default Argo CD install runs seven components and wants more than a gigabyte. This lab has about 3.4 GB free on `k3s-01` and 4 GB on `k3s-02` for everything that comes after (monitoring, the gateway, Hermes, Backstage), so Argo CD gets only what app-of-apps needs, with honest memory requests.
**Questions:**
- Chart version (default: the newest `argo-cd-*` release at `https://github.com/argoproj/argo-helm/releases` whose `appVersion` is a stable Argo CD 3.x, checked against `https://github.com/argoproj/argo-cd/releases`). The playbook was written against chart `10.11.6` / Argo CD `v3.5.6`.
- KSOPS version (default: newest at `https://github.com/viaduct-ai/kustomize-sops/releases`; written against `v4.5.1`).
- Keep the web UI? Default **yes**: it's how you'll see sync state and diffs, and it costs one small pod.
- UI address. Default `argocd.<k3s-01-ip>.nip.io`: nip.io is a public DNS service that answers `argocd.192.168.86.211.nip.io` with `192.168.86.211`, so no DNS server or hosts file is needed. Some routers block DNS answers that point at private addresses; the check in step 5 catches that, and the fallback is a hosts-file entry. A real lab DNS name comes with the DNS question (Pi, later).
- Components off: Dex (single sign-on; there's one user), notifications, and the ApplicationSet controller (app-of-apps doesn't need it; turn it on when apps are generated from folders). Default **all three off**.

**Actions:**
- `bootstrap/versions.env`: `ARGOCD_CHART_VERSION=<pinned>` and `KSOPS_VERSION=<pinned>`.
- Read the pinned chart's `values.yaml` (`helm show values argo/argo-cd --version <pinned>` after `helm repo add argo https://argoproj.github.io/argo-helm`) for the exact keys, since they move between chart versions. Then write `bootstrap/argocd/values.yaml` with:
  - `global.domain: argocd.<k3s-01-ip>.nip.io`.
  - `configs.params."server.insecure": true` (Traefik terminates TLS, Argo CD serves plain HTTP inside the cluster).
  - `server.ingress`: enabled, `ingressClassName: traefik`, annotations `traefik.ingress.kubernetes.io/router.entrypoints: websecure` and `traefik.ingress.kubernetes.io/router.tls: "true"` (HTTPS only, with Traefik's built-in self-signed certificate).
  - `dex.enabled: false`, `notifications.enabled: false`, and the ApplicationSet controller at `replicas: 0` (this chart has no `enabled` switch for it), unless the questions said otherwise.
  - KSOPS in the repo server, as in the KSOPS README's "Argo CD Helm Chart with Custom Tooling" section: `configs.cm."kustomize.buildOptions": "--enable-alpha-plugins --enable-exec"`; an `emptyDir` volume `custom-tools`; an init container `viaductoss/ksops:<KSOPS_VERSION>` running `ksops install --with-kustomize /custom-tools`; `kustomize` and `ksops` mounted into `/usr/local/bin/` with `subPath`. For age: a volume from the Secret `sops-age` mounted read-only at `/home/argocd/.config/sops/age`, and the env var `SOPS_AGE_KEY_FILE=/home/argocd/.config/sops/age/keys.txt`.
  - Resources, as a starting point to correct in step 4 with real numbers: controller requests `100m`/`256Mi`, limit `768Mi`; repo server `50m`/`128Mi`, limit `512Mi` (rendering Helm charts and decrypting spikes); server `25m`/`64Mi`, limit `256Mi`; Redis `25m`/`32Mi`, limit `128Mi`. No CPU limits (they throttle; requests are enough on a lab cluster).
  - `configs.cm."timeout.reconciliation": 180s` (the default: Git is polled every 3 minutes; there's no webhook because the cluster isn't reachable from GitHub).

**Verify:** `helm template argocd argo/argo-cd --version <pinned> -n argocd -f bootstrap/argocd/values.yaml > /tmp/argocd.yaml` succeeds; `grep -A3 '^kind: \(Deployment\|StatefulSet\)' /tmp/argocd.yaml | grep 'name:'` lists only the kept components (application controller, repo server, server, Redis, and the ApplicationSet controller at 0 replicas), no Dex or notifications; `grep -n 'viaductoss/ksops' /tmp/argocd.yaml` shows the pinned tag; `grep -n 'websecure' /tmp/argocd.yaml` shows the ingress annotation.
**Record:** Draft `docs/domains/platform/reference-argocd.md`: versions, what's on and off and why, memory settings.

### 3. The age key and SOPS rules
**Why:** SOPS encrypts only the values of a Secret, so diffs stay readable and the file is safe in a public repo; age is the simplest key type SOPS supports (one line, no keyring). The private key exists in three places only: your password manager, the Windows folder mounted into dev containers, and one Secret in the cluster. The agent never reads it ([ADR-0020](../../docs/decisions/0020-secrets-in-git-with-sops-age-ksops.md)).
**Questions:** One key for the whole lab, or one per cluster? Default **one key** (one cluster). A second recipient (a backup key kept offline)? Default **no**: the password manager is the backup.
**Actions:**
- Create the key only if it doesn't exist, without showing it: `test -e "$SOPS_AGE_KEY_FILE" || age-keygen -o "$SOPS_AGE_KEY_FILE"`. `age-keygen` prints only the public key (`age1...`), which is safe to show and to commit. To read the public key later: `age-keygen -y "$SOPS_AGE_KEY_FILE"`.
- 🧑 Copy the private key into your password manager from Windows: `notepad "$env:USERPROFILE\.sops-age\keys.txt"`, copy the line that starts with `AGE-SECRET-KEY-`, close Notepad without saving.
- `.sops.yaml` in the repo root:
```yaml
creation_rules:
  - path_regex: .*\.enc\.ya?ml$
    encrypted_regex: ^(data|stringData)$
    age: <public key, age1...>
```
  Only files named `*.enc.yaml` are encrypted, and only their `data` and `stringData` values, so names, namespaces and keys stay readable in diffs.

**Verify:** `age-keygen -y "$SOPS_AGE_KEY_FILE"` prints the same public key as `.sops.yaml`; `git grep -n AGE-SECRET-KEY` finds nothing; the agent tries to open `$SOPS_AGE_KEY_FILE` with its read tool and is **refused** (the `opencode.json` deny rule; if it's not refused, stop and fix `opencode.json` before going on).
**Record:** ADR-0020 (ask whether it still holds and set it `accepted`). Draft `docs/domains/platform/howto-secrets-sops.md`: how to add and edit a secret (below), how to rotate the key (`sops updatekeys`), what to do if the key is lost (new key, re-create every secret's values).

### 4. Bootstrap Argo CD with Helm
**Why:** Argo CD can't install itself from Git before it exists, so Helm installs it once, from the same chart version and values that Argo CD will use to manage itself in step 7. Rebuilding from an empty cluster is this one script.
**Actions:** Write `bootstrap/install.sh`, idempotent, run from the repo root in the dev container. It never prints a secret:
1. Read `bootstrap/versions.env`; fail if `$SOPS_AGE_KEY_FILE` doesn't exist.
2. `kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -`.
3. Create the `sops-age` Secret only if it's missing: `kubectl -n argocd get secret sops-age >/dev/null 2>&1 || kubectl -n argocd create secret generic sops-age --from-file=keys.txt="$SOPS_AGE_KEY_FILE"`. (Changing the key later is a deliberate step in the how-to, not something a rerun does.)
4. `helm repo add argo https://argoproj.github.io/argo-helm --force-update`, then `helm upgrade --install argocd argo/argo-cd --version "$ARGOCD_CHART_VERSION" -n argocd -f bootstrap/argocd/values.yaml --wait --timeout 10m`.
5. Apply `bootstrap/project.yaml` and `bootstrap/root.yaml` **only if they exist and `origin/main` contains them** (they come in step 7; until then the script stops after Helm).

Show the script, then run it. Then check memory and adjust the `resources` in the values if a pod's real use (`kubectl top pods -n argocd`) is far from its request; rerun the script after any change.
**Verify:** `kubectl -n argocd get pods` shows controller, repo server, server and Redis `Running` (and no Dex or notifications pod); `kubectl -n argocd logs deploy/argocd-repo-server -c install-ksops` shows the init container finished; `kubectl -n argocd exec deploy/argocd-repo-server -- ksops --help` prints its usage (the plugin is in place); `kubectl -n argocd describe secret sops-age` shows one key `keys.txt` with a byte count (describe never shows values); `kubectl top pods -n argocd` adds up to well under 1 GiB; running the script a second time changes nothing (`helm history argocd -n argocd` gains a revision but `kubectl -n argocd get pods` shows no restarts).
**Record:** Journal: memory per pod and per node (`kubectl top nodes`) before and after. `reference-argocd.md`: final resources.

### 5. First login 🧑
**Why:** The chart creates a one-time admin password. You replace it with your own and delete the one-time one, so no working password sits in the cluster in a form anyone with `kubectl` can read.
**Actions:**
- Agent: `getent hosts argocd.<k3s-01-ip>.nip.io` resolves to `k3s-01`'s address, and `curl -sk -o /dev/null -w '%{http_code}\n' https://argocd.<k3s-01-ip>.nip.io/healthz` prints `200`. If DNS fails, the router is filtering private answers: add `<k3s-01-ip> argocd.<k3s-01-ip>.nip.io` to `C:\Windows\System32\drivers\etc\hosts` (🧑, Notepad as administrator) and record it.
- 🧑 In **your own terminal** (not the agent's): `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo`.
- 🧑 Open `https://argocd.<k3s-01-ip>.nip.io` in your browser, accept the self-signed certificate warning, log in as `admin` with that password. **User Info → Update password**: set a long one, save it in the password manager. Tell the agent "done".
- Agent: `kubectl -n argocd delete secret argocd-initial-admin-secret`.

**Verify:** `kubectl -n argocd get secret argocd-initial-admin-secret` says `NotFound`; 🧑 you can log out and back in with the new password.
**Record:** `reference-argocd.md`: UI address, certificate note, where the admin password lives (password manager only). The agent's CLI access uses the kubeconfig (`argocd ... --core`), not this password.

### 6. CI and branch protection
**Why:** From step 7 on, merging to `main` changes the cluster. So `main` gets the same protection as the other repos, plus two checks that matter for GitOps in a public repo: no unencrypted secret ever lands, and the bootstrap pin can't drift from what Argo CD runs.
**Actions:**
- `scripts/check-secrets.sh`: every `*.enc.yaml` has a top-level `sops:` block and every value under `data`/`stringData` starts with `ENC[`; no other YAML file contains `kind: Secret` (Argo CD and KSOPS generate the real ones). Exit non-zero with the file name on failure.
- `scripts/check-versions.sh`: `ARGOCD_CHART_VERSION` from `bootstrap/versions.env` equals the chart `targetRevision` in `apps/argocd.yaml` (once it exists), and the `viaductoss/ksops` tag in the values equals `KSOPS_VERSION`.
- `.github/workflows/ci.yml`, one job `ci` like `homelab-infra`'s: pinned gitleaks CLI; `shellcheck` (pinned) over `bootstrap/*.sh scripts/*.sh`; both scripts above; YAML parse of every `*.yaml`; `helm template` of the pinned chart with the values, piped into `kubeconform` (pinned, `-strict -summary`, with `-ignore-missing-schemas` only for Argo CD's own CRDs, or with the CRDs-catalog schema location for `argoproj.io` kinds).
- Enable Dependabot alerts, secret scanning and push protection on the repo (repo Settings → Advanced Security, or `gh api` as in playbook 01). Open a PR with everything so far. Once `ci` is green and merged, add the `protect-main` ruleset with `ci` required ([how-to](../../docs/domains/github/howto-rulesets.md), with this repo's name).

**Verify:** On a throwaway branch, commit a plain `kind: Secret` file and see `ci` fail on it, then delete the branch without merging. `ci` green on the PR; 🧑 you squash-merge it; `gh api repos/ssaav5-ai-labs/homelab-gitops/rulesets --jq '.[].name'` lists `protect-main`.
**Record:** Journal: the deliberate failure and its error message.

### 7. App-of-apps: Argo CD takes over itself
**Why:** After this step, nobody runs `helm` against the cluster any more. A change to Argo CD (version, values) is a PR to `apps/argocd.yaml` or `bootstrap/argocd/values.yaml`; Argo CD sees the merge and syncs itself. The root app makes every new file in `apps/` a new app ([ADR-0019](../../docs/decisions/0019-gitops-with-argo-cd-app-of-apps.md)).
**Questions:** Automatic sync with self-heal for everything? Default **yes**, with `prune: true` for normal apps and `prune: false` for `argocd` itself (a bad change must never make Argo CD delete its own pieces).
**Actions:**
- `bootstrap/project.yaml`: an `AppProject` `platform` whose source repos are only `https://github.com/ssaav5-ai-labs/homelab-gitops.git` and `https://argoproj.github.io/argo-helm`, destination the in-cluster server, all namespaces, cluster resources allowed (the lab's platform apps install CRDs).
- `bootstrap/root.yaml`: Application `root` in `argocd`, project `platform`, source this repo, `targetRevision: main`, `path: apps`, `directory.recurse: false`, automated sync with `prune: true` and `selfHeal: true`. **No** `resources-finalizer` on `root`, so deleting the root app never cascades into deleting everything.
- `apps/argocd.yaml`: Application `argocd`, project `platform`, **two sources**: the chart `argo-cd` from `https://argoproj.github.io/argo-helm` at `targetRevision: <ARGOCD_CHART_VERSION>` with `helm.releaseName: argocd` and `helm.valueFiles: [$values/bootstrap/argocd/values.yaml]`; and this repo at `main` with `ref: values`. Automated sync with `selfHeal: true`, `prune: false`; `syncOptions: [ServerSideApply=true]` (Argo CD's CRDs are too big for client-side apply's annotation).
- PR, `ci` green, 🧑 squash-merge. Then the agent runs `bootstrap/install.sh` again, which now applies the project and root app.

**Verify:** `kubectl -n argocd get applications` shows `root` and `argocd` both `Synced` and `Healthy` within a few minutes (`argocd app list --core` shows the same); `kubectl -n argocd get pods` shows no pod restarted by the takeover (same values, so nothing changes); in the UI, the `argocd` app's diff is empty. `scripts/check-versions.sh` passes.
**Record:** `reference-argocd.md`: how to upgrade Argo CD (bump `ARGOCD_CHART_VERSION` and the `targetRevision` together, CI checks they match), and why `prune` is off for `argocd`.

### 8. A secret through the whole path: the SOPS canary
**Why:** Proves, once and on every future sync, that an encrypted file in a public repo becomes a real Secret in the cluster and that only the cluster and you can read it. Playbook 05 then stores real secrets the same way (Grafana, the gateway's keys).
**Actions:**
- `platform/sops-canary/`: `namespace.yaml` (`sops-canary`); `secret.enc.yaml`, a Secret `canary` with `stringData: {canary: "sops-works"}` (not a secret value, so the agent may write it), encrypted in place with `sops encrypt -i platform/sops-canary/secret.enc.yaml`; `secret-generator.yaml`, a KSOPS generator (`apiVersion: viaduct.ai/v1`, `kind: ksops`, `files: [./secret.enc.yaml]`, the `config.kubernetes.io/function` annotation with `exec: {path: ksops}`); `kustomization.yaml` with `resources: [namespace.yaml]` and `generators: [secret-generator.yaml]`.
- `apps/sops-canary.yaml`: Application `sops-canary`, project `platform`, `path: platform/sops-canary`, automated with prune and self-heal.
- PR (CI checks the file is encrypted), 🧑 squash-merge.

How you add a **real** secret later (for `howto-secrets-sops.md`): you, in your own terminal, run `sops edit platform/<app>/<name>.enc.yaml` (SOPS opens an editor on the decrypted file and re-encrypts when you save), then commit. The agent writes the generator, kustomization and app, and leaves a placeholder file for you to fill; it never decrypts (`sops decrypt` is denied in `opencode.json`).

**Verify:** `sops-canary` is `Synced` and `Healthy`; `kubectl -n sops-canary describe secret canary` shows key `canary` with `10 bytes`; `git show HEAD:platform/sops-canary/secret.enc.yaml | grep -c 'ENC\['` is at least 1 and `grep -c sops-works` on it is 0. 🧑 In your own terminal, `kubectl -n sops-canary get secret canary -o jsonpath='{.data.canary}' | base64 -d; echo` prints `sops-works`.
**Record:** `howto-secrets-sops.md` (final), journal.

### 9. Drills: Git wins
**Why:** Self-heal is the point of GitOps and the thing to trust before real workloads arrive. These are cheap now and impossible to rehearse calmly later.
**Actions:**
- **Deleted resource:** `kubectl -n sops-canary delete secret canary`; within a minute, `kubectl -n sops-canary get secret canary` shows it back (a new `AGE`).
- **Hand edit:** `kubectl -n argocd scale deploy argocd-server --replicas=0`; Argo CD sets it back to 1 within a minute (self-heal on the `argocd` app), and the UI comes back.
- **Change through Git:** in a PR, change the canary value to `sops-works-2` (🧑 with `sops edit` in your terminal, since the file is encrypted), merge, and wait up to 3 minutes: `describe` shows `12 bytes`.
- **Node reboot:** `kubectl drain k3s-02 --ignore-daemonsets --delete-emptydir-data`, 🧑 reboot `k3s-02`, `kubectl uncordon k3s-02`; all apps return to `Synced`/`Healthy` without help.

**Verify:** Each drill ends with every application `Synced` and `Healthy`.
**Record:** `docs/domains/platform/runbook-rebuild-argocd.md`: rebuilding Argo CD on an empty cluster (age key from the password manager into `%USERPROFILE%\.sops-age\keys.txt`, kubeconfig, `bootstrap/install.sh` twice: before and after `main` has the apps; first login as in step 5). Mark it **untested** unless you choose to rehearse it on a rebuilt cluster.

### 10. Make the key mount the default for every repo
**Why:** Playbooks 05 to 08 work in other repos that also need `sops`. The mount you added by hand in *Before you start* belongs in the base template, and the tools this repo uses belong in its image, so a rebuilt container has them.
**Actions:**
- In the `workstation` repo (clone it to `/tmp`, branch, PR, like playbook 03 step 9): add the `.sops-age` mount and `SOPS_AGE_KEY_FILE` to `devcontainer/devcontainer.json`. While there, bump `SOPS_VERSION` and `AGE_VERSION` in `devcontainer/Dockerfile` to current releases (looked up, not from memory).
- In `homelab-gitops/.devcontainer/Dockerfile`: add pinned `argocd` CLI (same version as the server) and `kubeconform` (same as CI), and the same `sops`/`age` bumps. For this session, put the two binaries in `~/.local/bin` so they're usable now; the Dockerfile makes them permanent after a rebuild.
- Write `docs/domains/workstation/index.md`'s mounts section: the `.sops-age` mount and why.

**Verify:** The `workstation` PR's checks pass (🧑 approve and merge). The rebuild check happens after the session (step 11).
**Record:** Journal.

### 11. Finish
**Actions:** Close the journal entry (what broke, Argo CD memory per pod and per node, how long a merge takes to reach the cluster, the drills). Fill in `docs/domains/platform/index.md` (what exists, the diagram from this playbook, links to `reference-argocd`, `howto-secrets-sops`, `runbook-rebuild-argocd`, ADRs 0019 and 0020). ADR-0019: ask whether it still holds and set it `accepted`. In the open questions, close "GitOps controller" and "Secrets management" with ADR-0019 and ADR-0020. Update the playbook catalog (04 done, with the date). Remind the human to export the session and check it with `grep -cE 'sk-or-v1-[0-9a-f]{20}|sk-lf-[0-9a-f-]{20}|homelab-infra=[0-9a-f]{8}-|K3S_TOKEN=[0-9a-f]{16}|client-key-data: [A-Za-z0-9]|BEGIN OPENSSH|AGE-SECRET-KEY-1[0-9A-Z]{20}'` (real values only) before sharing. Open the handbook PR.
**After the session 🧑:** exit OpenCode, then in PowerShell `devpod up $r --recreate --ide none` and open a shell in the new container (the `docker ps` and `docker exec` lines from *Before you start*). There: `gh auth login` again, then `echo $SOPS_AGE_KEY_FILE` and `age-keygen -y "$SOPS_AGE_KEY_FILE"` (prints the public key: the key survived), `argocd version --client`, and `kubectl -n argocd get applications`.

## When it's done
- Code: `homelab-gitops` (bootstrap, apps, `platform/sops-canary`, CI with the secret and version checks) and the `workstation` template with the age key mount.
- Docs updated: `docs/domains/platform/` (index, reference-argocd, howto-secrets-sops, runbook-rebuild-argocd), ADRs 0019 and 0020, workstation index, open questions, playbook catalog, journal.
- Next playbook: 05 monitoring and the gateway on the cluster, deployed as apps in this repo, with their secrets in SOPS.

## Video
Not recorded yet. Good candidates: step 7 ("Argo CD upgrading itself from a pull request") and step 9 ("delete it and watch it come back").
