# Temporal Worker Controller

The [Temporal Worker Controller](https://github.com/temporalio/temporal-worker-controller) runs
Temporal workers as versioned `WorkerDeployment`s: it keeps several worker versions alive at once,
routes new workflows to the target version on a schedule, and retires an old version only after the
workflows pinned to it drain. Chart `0.31.0` / app `1.12.0`. Stay on app 1.11 or later: earlier
releases never scale a draining version back up from 0 replicas, so it can never drain
([temporal-worker-controller#587](https://github.com/temporalio/temporal-worker-controller/pull/587)).

Installs into the `temporal-worker-controller` namespace. Upstream docs use `temporal-system`; this
repo's convention is directory name == namespace, so it is named after the component instead.

## Why this component does not use `helmCharts:`

Every other chart here installs through `kustomization.yaml` `helmCharts:` and the
`kustomize-build-with-helm` CMP. Both charts here are published **OCI-only**
(`oci://docker.io/temporalio/…`), and this directory was originally built on the belief that
kustomize could not pull OCI charts. **That was wrong:** kustomize has supported
`repo: oci://...` since v5.2.0
([kustomize#5167](https://github.com/kubernetes-sigs/kustomize/pull/5167)), and this cluster's
Argo CD v3.0.11 bundles kustomize 5.6.0. Rendering both 0.31.0 charts inside the repo-server works,
with two catches:

- The CRDs chart ships no `values.yaml`, so the entry needs a `valuesFile:` pointing at a `{}` file,
  or kustomize fails with `evalsymlink failure on .../values.yaml`.
- Every entry needs `namespace: temporal-worker-controller`. Without it, the chart renders into the
  repo-server's own namespace (`argocd`): the webhook Service reference, the Certificate's DNS
  names and the cert-manager CA-injection annotation all point there.

Each chart still gets its own Argo CD `Application` with a native Helm source, which Argo CD v3
handles directly and which Renovate already tracks. Note the OCI convention: `repoURL` omits the
`oci://` prefix (`registry-1.docker.io/temporalio`). The directory is picked up by the
`infrastructure/controllers/*` ApplicationSet, so this is an app-of-apps leaf. Collapsing it into
a single `helmCharts:` Application is a valid alternative if the ordering issue below ever bites.

## Layout and ordering

| File | Wave | What |
|---|---|---|
| `ns.yaml` | `-9` | the namespace |
| `crds-app.yaml` | `-8` | CRDs chart — a manager that starts before its definitions crash-loops |
| `controller-app.yaml` | `-7` | the controller itself |

Sync waves are set per resource rather than through `commonAnnotations`, which would overwrite them
with a single value and lose the CRDs-before-controller ordering.

**The `-8` → `-7` wave does not actually wait.** Argo CD removed health assessment of
`argoproj.io/Application` in v1.8, and this cluster's `argocd-cm` does not restore it, so a child
Application counts as healthy the moment it exists and the next wave starts immediately. On an
upgrade this is harmless, since the CRDs are already there. On a from-scratch install the manager
may start before its CRDs and crash-loop until they arrive. The fixes are restoring
`resource.customizations.health.argoproj.io_Application` (a cluster-wide behaviour change for every
app-of-apps) or installing both charts from one Application, where Argo's kind ordering puts CRDs
first.

The child Applications are named `temporal-worker-controller-crds` and
`temporal-worker-controller-manager`. They **must not** be named `temporal-worker-controller` —
the ApplicationSet already generates an app with that name from this directory.

## Dependencies

- **cert-manager** — the `WorkerResourceTemplate` validating webhook is always on and needs TLS, so
  the chart's `certmanager.enabled: true` creates an Issuer and Certificate. cert-manager itself is
  its own infrastructure component; chart 0.30.0 removed the bundled subchart and the
  `certmanager.install` key, and since this repo always had it `false`, no migration was needed.
  On a from-scratch cluster rebuild the ApplicationSet gives every infrastructure app the same app-level wave, so this may
  sync before cert-manager; the controller crash-loops until the Certificate exists, then recovers.
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

Two tempting fixes are **not available in chart 0.29.1**: it exposes no manager-level `extraArgs`
(so `--leader-elect=false` cannot be turned off for the single replica, which does not need it) and
no probe overrides (so `timeoutSeconds` cannot be loosened). The `extraArgs` key in `values.yaml`
belongs to the `kubeRBACProxy` sidecar, not the manager — do not be fooled by it. Reaching either
knob means giving up the native Helm-OCI source for vendored `helm template` output and kustomize
patches, which costs Renovate coverage. Not worth it while raising the request fixes the cause.

If this recurs after the request bump, check node contention first (`kubectl describe node`) before
touching the controller.

No secrets: an in-cluster `Connection` to `temporal-frontend.temporal.svc.cluster.local:7233` is
plaintext, so no mTLS or API-key secret is involved.

## Deleting this component

The Applications carry no `resources-finalizer.argocd.argoproj.io`, so removing them leaves the
CRDs and controller in the cluster rather than cascading. That is deliberate — deleting the CRDs
would take every `WorkerDeployment` with it, and with them the workers running pinned workflows.
Clean up by hand if you really mean it.

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

Bump `targetRevision` in both Applications together. The CRDs chart is backwards compatible, so the
non-gating waves above do not matter here. Before bumping, check the controller's
`internal/k8s/deployments.go` `ComputeBuildID` for changes: if a release changes how Build IDs are
derived, the upgrade itself starts a new version rollout on every `WorkerDeployment`. 0.29.1 →
0.31.0 did not. 1.12.0 reads the template through the new `spec.deployment` field but falls back to
`spec.template`, which hashes the same.
