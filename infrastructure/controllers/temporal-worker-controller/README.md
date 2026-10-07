# Temporal Worker Controller

The [Temporal Worker Controller](https://github.com/temporalio/temporal-worker-controller) runs
Temporal workers as versioned `WorkerDeployment`s: it keeps several worker versions alive at once,
routes new workflows to the target version on a schedule, and retires an old version only after the
workflows pinned to it drain. Chart `0.31.0` / app `1.12.0`. Stay on app 1.11 or later: earlier
releases never scale a draining version back up from 0 replicas, so it can never drain
([temporal-worker-controller#587](https://github.com/temporalio/temporal-worker-controller/pull/587)).

Installs into the `temporal-worker-controller` namespace. Upstream docs use `temporal-system`; this
repo's convention is directory name == namespace, so it is named after the component instead.

## How it installs

Like every other chart in this repo, both charts render through `kustomization.yaml` `helmCharts:`
and the `kustomize-build-with-helm` CMP (`kustomize build --enable-helm`), as part of the
`temporal-worker-controller` Application that the `infrastructure/controllers/*` ApplicationSet
generates. Both charts are published **OCI-only**; kustomize has pulled `repo: oci://...` since
v5.2.0 ([kustomize#5167](https://github.com/kubernetes-sigs/kustomize/pull/5167)), and Argo CD
v3.0.11 bundles 5.6.0.

| File | What |
|---|---|
| `ns.yaml` | the namespace |
| `kustomization.yaml` | both `helmCharts:` entries — CRDs chart, then the controller |
| `values.yaml` | controller chart values (see below) |
| `empty-values.yaml` | `{}` for the CRDs chart, which ships no `values.yaml` of its own |

Three things in `kustomization.yaml` look optional and are not:

- **`valuesFile: empty-values.yaml` on the CRDs chart.** Without it kustomize fails right after the
  pull with `evalsymlink failure on .../temporal-worker-controller-crds/values.yaml`.
- **`namespace:` on every entry.** Without it Helm renders into the repo-server's own namespace
  (`argocd`): the webhook Service reference, the Certificate's DNS names and the cert-manager
  CA-injection annotation all point there, and the webhook breaks.
- **The `releaseName`s.** `temporal-worker-controller-crds` and `temporal-worker-controller-manager`
  are the names of the two Argo CD Applications that installed these charts until 2026-10-07 (Argo
  uses the Application name as the Helm release name). Keeping them kept every object name the
  same, so this directory adopted the live resources in place instead of installing a second
  controller next to orphaned ones. Changing a release name now renames every object.

**Ordering needs no sync waves.** Within one Application, Argo applies by kind — Namespace, then
CustomResourceDefinitions, then everything else — so the CRDs always land before the manager. The
previous layout put each chart in its own child Application with `-8`/`-7` waves, and those waves
never actually gated anything: Argo CD removed `argoproj.io/Application` health in v1.8 and this
cluster's `argocd-cm` does not restore it, so a child Application counted as healthy the moment it
existed.

## Dependencies

- **cert-manager** — the `WorkerResourceTemplate` validating webhook is always on and needs TLS, so
  the chart's `certmanager.enabled: true` creates an Issuer and Certificate. cert-manager itself is
  its own infrastructure component; chart 0.30.0 removed the bundled subchart and the
  `certmanager.install` key, and since this repo always had it `false`, no migration was needed.
  On a from-scratch cluster rebuild the ApplicationSet gives every infrastructure app the same
  app-level wave, so this may sync before cert-manager; the controller crash-loops until the Certificate exists, then recovers.
- **Docker Hub** — charts and the controller image pull from `registry-1.docker.io` anonymously,
  which is rate-limited.

## Chart values worth knowing

- `replicas: 1` — the chart defaults to 2, which does not fit a single node.
- `metrics.disableAuth: true` — removes the kube-rbac-proxy sidecar. Set it back to `false` if the
  metrics endpoint is ever exposed beyond the cluster.
- `rbac.restrictWatchNamespaces` is left unset, so the controller watches all namespaces with
  cluster-wide RBAC. Set it to a list once the namespaces holding `WorkerDeployment`s are known.
- `resources.requests.cpu: 100m` — **deliberately 10x the chart default.** See below.

## The 10m CPU request crash loop

Between the 2026-09-15 install and the same day's fix, the manager restarted 52 times in 14 hours,
roughly once every 16 minutes, while doing nothing at all — no `WorkerDeployment` existed yet.
Symptoms came in two shapes that look unrelated but share one cause:

```
Error retrieving lease lock ... context deadline exceeded
Failed to renew lease
setup: problem running manager  error="leader election lost"     # exit 1
Liveness probe failed: .../healthz: context deadline exceeded
```

The chart's default `requests.cpu: 10m` buys a negligible CFS share on a node running at 70% CPU
requests and 655% limit overcommit. Starved, the manager cannot serve its own `/healthz` within the
chart's `livenessProbe.timeoutSeconds: 1`, and cannot renew its leader-election lease within the
client's 5s deadline. Either one kills the pod. Exit code 1 rather than 137 is the tell that this
was never memory.

Two tempting fixes are **still not exposed as chart values** (checked through 0.31.0): there is no
manager-level `extraArgs` (so `--leader-elect` cannot be dropped for the single replica, which does
not need it) and no probe overrides (so `timeoutSeconds` cannot be loosened). The `extraArgs` key in
`values.yaml` belongs to the `kubeRBACProxy` sidecar, not the manager — do not be fooled by it.
Now that the charts render through kustomize, either knob is reachable with a `patches:` entry on the
`temporal-worker-controller-manager-manager` Deployment, with no loss of Renovate coverage. Not
needed while raising the request fixes the cause.

If this recurs after the request bump, check node contention first (`kubectl describe node`) before
touching the controller.

No secrets: an in-cluster `Connection` to `temporal-frontend.temporal.svc.cluster.local:7233` is
plaintext, so no mTLS or API-key secret is involved.

## Deleting this component

The ApplicationSet-generated `temporal-worker-controller` Application carries
`resources-finalizer.argocd.argoproj.io`, so deleting this directory cascades to everything it
manages — **including the CRDs**, and with them every `WorkerDeployment` and the workers running
pinned workflows. That is the same trade-off every other CRD-shipping component here (Longhorn,
external-secrets, Cilium, …) already makes, so it is accepted rather than guarded against. If that
ever needs to change, add `argocd.argoproj.io/sync-options: Delete=false,Prune=false` to the CRDs
with a kustomize patch, or set `preserveResourcesOnDeletion` on the ApplicationSet for every
component at once.

## Verifying

```bash
kubectl -n temporal-worker-controller get deploy,pod
kubectl api-resources --api-group=temporal.io
```

Expect `workerdeployments`, `connections`, `clusterconnections` and `workerresourcetemplates`.
The deprecated `temporalworkerdeployments` and `temporalconnections` also appear — they still ship
in the CRDs chart but have been unmanaged since app v1.7.0, so use the short names.

Requires a Temporal server **≥ 1.29.1**; `services/temporal/` runs 1.31.0 via chart 1.2.0, and
`system.enableDeploymentVersions` defaults to true there, so no dynamic config change is needed.

Its consumer is `applications/worker-versioning/`, the versioning test harness.

## Upgrading

Bump `version` on both `helmCharts:` entries together (Renovate's `kustomize` manager tracks them).
One Application applies both, CRDs first by kind ordering. Before bumping, check the controller's
`internal/k8s/deployments.go` `ComputeBuildID` for changes: if a release changes how Build IDs are
derived, the upgrade itself starts a new version rollout on every `WorkerDeployment`. 0.29.1 →
0.31.0 did not. 1.12.0 reads the template through the new `spec.deployment` field but falls back to
`spec.template`, which hashes the same.
