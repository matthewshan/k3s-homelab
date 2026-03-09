## Plan: Add Grafana Monitoring App

Create a new infrastructure-managed Argo CD application for Grafana k8s-monitoring by adding a new `infrastructure/monitoring/*` generator path, introducing a `monitoring` kustomize package that renders the Helm chart from `infrastructure/monitoring/helm.md`, and wiring credentials through pre-created Kubernetes Secrets. This follows the repo's existing Helm-plus-kustomize infrastructure pattern and the repo's current manual secret creation convention.

**Steps**

1. Update AppSet discovery in `infrastructure/infrastructure-components-appset.yaml` to include `infrastructure/monitoring/*` so a top-level monitoring component is auto-generated. This is required before any new monitoring folder will be reconciled.
2. Create the new component directory structure under `infrastructure/monitoring/grafana-k8s-monitoring` or, if you want the application name to stay exactly `monitoring`, flatten the component directly under `infrastructure/monitoring`. Choose one shape before implementation because `path.basename` controls both the Argo application name and target namespace.
3. Add `kustomization.yaml` for the new monitoring component using the same pattern as cert-manager, cilium, and longhorn: include `ns.yaml` in `resources`, define a `helmCharts` entry for `grafana/k8s-monitoring`, set `releaseName`, `namespace`, chart `version`, `repo`, and `valuesFile`, and add `includeCRDs` only if confirmed necessary for the selected chart version.
4. Add `ns.yaml` for the `monitoring` namespace unless you deliberately rely on `CreateNamespace=true` alone. Keeping an explicit namespace manifest matches current infrastructure patterns such as cert-manager and longhorn.
5. Convert the inline install values from `infrastructure/monitoring/helm.md` into a tracked `values.yaml`, keeping the same functional sections: `cluster`, `destinations`, `clusterMetrics`, `clusterEvents`, `podLogs`, `applicationObservability`, and the `alloy-*` blocks. Preserve the existing `extraEnv` wiring already shown in the markdown where it is still needed by the chart.
6. Replace all placeholder secret literals with the chart's supported secret-backed fields. For external service auth in `destinations[*].auth` and `alloy-*.remoteConfig.auth`, use `passwordKey` and `usernameKey` where needed together with the per-destination `secret` block set to `create: false`, `name`, and `namespace`. Use `passwordFrom` only where raw Alloy expressions are required instead of simple secret-key lookups.
7. Define the secret contract in repo documentation rather than committing live credentials. Document one or more `kubectl create secret generic` commands for the `monitoring` namespace that create the secrets expected by `values.yaml`. A minimal first pass can use separate secrets matching the names already implied in `helm.md`, such as `grafana-cloud-metrics-grafana-k8s-monitoring`, `alloy-metrics-remote-cfg-grafana-k8s-monitoring`, `alloy-singleton-remote-cfg-grafana-k8s-monitoring`, `alloy-logs-remote-cfg-grafana-k8s-monitoring`, and `alloy-receiver-remote-cfg-grafana-k8s-monitoring`.
8. Add a short README or extend `infrastructure/monitoring/helm.md` to capture the manual bootstrap steps for secrets, mirroring the style already used for cert-manager in `docs/setup.md` and the commented guidance in `infrastructure/controllers/cert-manager/cloudflare-secret.yaml`.
9. Validate the rendered manifests before handoff: ensure the appset now discovers the monitoring path, confirm kustomize with helm renders successfully, and verify the values use only chart-supported secret fields rather than unsupported native Kubernetes `secretKeyRef` in auth password properties.

**Relevant Files**

- `infrastructure/infrastructure-components-appset.yaml`: add `infrastructure/monitoring/*` generator path.
- `infrastructure/kustomization.yaml`: likely unchanged unless you want any top-level resource ordering adjustments.
- `infrastructure/monitoring/helm.md`: source material for the Helm values and a good place to keep bootstrap notes if no README is added.
- `infrastructure/monitoring/kustomization.yaml` or `infrastructure/monitoring/grafana-k8s-monitoring/kustomization.yaml`: main kustomize entry for the new component.
- `infrastructure/monitoring/values.yaml` or `infrastructure/monitoring/grafana-k8s-monitoring/values.yaml`: chart configuration translated from the markdown install command.
- `infrastructure/monitoring/ns.yaml` or `infrastructure/monitoring/grafana-k8s-monitoring/ns.yaml`: explicit namespace manifest.
- `docs/setup.md`: optional place to add the monitoring secret bootstrap commands if you want all cluster bootstrap secrets centralized.
- `infrastructure/controllers/cert-manager/kustomization.yaml`: reference pattern for Helm chart plus namespace resource.
- `infrastructure/storage/longhorn/kustomization.yaml`: reference pattern for Helm chart plus CRDs.
- `infrastructure/networking/cloudflared/kustomization.yaml`: reference pattern for manual secret handling documentation.

**Verification**

1. Confirm the ApplicationSet generator includes `infrastructure/monitoring/*` and that the resulting app name and namespace behavior matches the chosen directory shape.
2. Run a local render with the same mechanism Argo expects, such as `kustomize build --enable-helm <monitoring-component-path>`, and inspect that the Helm chart expands successfully.
3. Check that every remote auth stanza uses chart-supported secret fields like `passwordKey`, `usernameKey`, `bearerTokenKey`, `urlFrom`, or `passwordFrom` rather than unsupported Kubernetes `secretKeyRef` directly inside destination auth blocks.
4. Verify the manual secret creation commands produce secret names and keys that exactly match the `values.yaml` references.
5. If the chart version introduces CRDs or cluster-scoped RBAC, confirm they are allowed by the existing `infrastructure` AppProject, which is currently permissive enough.

**Decisions**

- Monitoring should remain a top-level infrastructure category, so the ApplicationSet must be expanded rather than reclassifying the component under `controllers` or `networking`.
- Initial secret handling should follow the repo's current manual secret creation pattern with `kubectl create secret generic`; no new secret operator is in scope.
- The Grafana k8s-monitoring chart does support reading from pre-existing Kubernetes Secrets, but not via native Kubernetes `secretKeyRef` in the auth password fields. The supported pattern is `passwordKey` and related `*Key` fields plus `secret.create: false`, with `passwordFrom` available for raw Alloy expressions.
- Avoid committing real secret manifests or secret values to git.

**Further Considerations**

1. Directory shape recommendation: use `infrastructure/monitoring/grafana-k8s-monitoring` if you expect more monitoring components later; use `infrastructure/monitoring` only if this category will stay single-purpose and you want the namespace and app name to remain simply `monitoring`.
2. Documentation recommendation: keep operational secret bootstrap commands in `docs/setup.md` if you want one cluster bootstrap guide, or add a dedicated monitoring README if you want service-local instructions.
3. Secret design recommendation: one shared secret can reduce duplication, but separate secrets per destination and remoteConfig block align more closely with the names already implied by the current markdown and make rotations more targeted.