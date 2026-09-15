# Argo CD

## Diff customizations

- Argo CD system-level diff ignores live in `infrastructure/controllers/argocd/values.yaml` under `configs.cm.resource.customizations.ignoreDifferences.*`.
- The `twingateresourceaccesses.twingate.com` CRD ignores `.spec.versions[]?.schema.openAPIV3Schema.properties.spec.oneOf[]?.properties`.
- This avoids persistent drift when the API server normalizes an omitted schema field to `properties: null` for the Twingate CRD.
- Keep this rule scoped to the specific CRD name unless additional CRDs show the same normalization behavior.

## Health customizations

- Argo CD computes application health from a built-in registry of known kinds. For an API group it
  does not know — `temporal.io` included — it skips the resource entirely rather than falling back
  to inspecting `status.conditions`.
- Without a custom check, an application containing a `WorkerDeployment` reports **Healthy** as soon
  as the manifest syncs, while the rollout has not begun. A Progressive rollout can take 20 minutes,
  so that is the difference between watching a rollout and being told a lie about it.
- `resource.customizations.health.temporal.io_WorkerDeployment` in
  `infrastructure/controllers/argocd/values.yaml` reads the two standard conditions the controller
  sets: `Ready=True` → Healthy, `Progressing=True` → Progressing, `Progressing=False` → Degraded,
  neither present yet → Progressing. The condition's own `message` is passed through, so the
  controller's reason (`WaitingForPollers`, `AuthSecretInvalid`, …) shows in the UI without digging.
- The kind segment of the key must match what `kubectl api-resources --api-group=temporal.io`
  registered (`WorkerDeployment`). A mismatched key fails **silently** — no error, just no health.
- `argocd-cm` changes are normally picked up without a restart. If health does not change within a
  reconcile, restart `deploy/argocd-application-controller` before suspecting the Lua.
