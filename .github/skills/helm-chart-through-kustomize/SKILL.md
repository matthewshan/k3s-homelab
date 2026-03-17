---
name: helm-chart-through-kustomize
description: 'Install a Helm chart in this homelab repo using Kustomize helmCharts, matching the repo structure, secret handling, validation, and documentation standards.'
argument-hint: 'What chart should be installed, where should it live in the repo, and what companion resources or access pattern does it need?'
user-invocable: true
---

# Install Helm Chart Through Kustomize

Use this skill when adding a new Helm chart-backed component to this repository. The goal is to install the chart in the repo's GitOps style: declare it in a component-local `kustomization.yaml`, keep overrides in `values.yaml`, add companion Kubernetes manifests beside it, and document only the operational details that cannot be expressed directly in Git.

This repo is organized around Argo CD ApplicationSets and separates components into `infrastructure/`, `services/`, and `applications/`. Argo CD sources these paths through the `kustomize-build-with-helm` plugin, so local validation should mirror that Helm-enabled Kustomize flow. Prefer repo-managed manifests over imperative cluster changes.

## When to Use

- You need to add a new Helm chart-based component to this repo.
- An existing raw-manifest deployment should be replaced with a chart managed through Kustomize.
- A new service, infrastructure component, or application needs chart-based installation that fits the repo's current layout.
- You need repo-standard guidance for chart version pinning, values structure, secrets, and validation.

## Repo Standards

- Prefer `helmCharts` in `kustomization.yaml` over checked-in rendered manifests.
- Keep chart lifecycle wiring in `kustomization.yaml` and chart overrides in `values.yaml`.
- Match the repo's component layout: keep `kustomization.yaml`, `values.yaml`, `ns.yaml` or `namespace.yaml`, and any companion manifests in the same component directory.
- Never commit real secrets in `values.yaml`. Use existing Kubernetes `Secret` references or documented secret creation steps.
- Prefer Git-tracked desired state over out-of-band operational changes.
- Add docs only for repo-specific operational details another operator will need later.
- Do not edit `docs/setup.md` unless the user explicitly asks for it.

## Procedure

1. Classify the component before creating files.

Decide where it belongs:
- `infrastructure/` for cluster capabilities and controllers such as networking, storage, monitoring, or platform services
- `services/` for self-hosted services exposed for ongoing use
- `applications/` for smaller apps or utility workloads managed similarly to end-user apps

If placement is unclear, state the tradeoff and ask the user to choose before making a large structural change.

2. Create the component directory using the repo's local pattern.

The component folder should usually contain:
- `kustomization.yaml`
- `values.yaml`
- `ns.yaml` or `namespace.yaml`
- any companion manifests the chart does not or should not manage, such as `HTTPRoute`, PVCs, service accounts, RBAC bindings, or certificate resources
- a `README.md` when the component needs operator-facing setup, access, secret creation, or upgrade notes

Follow nearby examples in the same top-level area before inventing a new structure.

3. Verify the Helm chart source and version.

Before pinning a version:
- identify the upstream chart repository URL
- verify the latest suitable chart release
- use that version unless the repo already requires an older pinned version for a documented reason

Record the chart in `kustomization.yaml` using `helmCharts` with fields like:
- `name`
- `repo`
- `version`
- `releaseName`
- `namespace`
- `valuesFile`
- `includeCRDs: true` only when the chart ships CRDs that must be installed with it

Use a stable, readable `releaseName`, usually the component name.

4. Write the Kustomize entry in the repo's style.

For chart-backed components, prefer a component-local `kustomization.yaml` that:
- includes the namespace manifest in `resources`
- includes companion manifests that are repo-managed outside the chart
- sets `namespace:` when the surrounding component pattern does so
- adds `commonLabels` only when the surrounding folder already uses them or the repo clearly benefits from them
- references `values.yaml` through `valuesFile`

Do not check in rendered chart output.

5. Keep `values.yaml` minimal and repo-specific.

Only override what this repo actually cares about, such as:
- ingress or Gateway API integration being handled outside the chart
- service type and ports
- persistence settings
- service account or RBAC toggles when those resources are managed separately
- resource requests and limits
- chart features that conflict with repo-managed manifests

Avoid copying the full default values file. Keep comments short and only where they clarify a repo-specific decision.

6. Handle secrets safely.

If the chart needs credentials:
- prefer referencing an existing Kubernetes `Secret` by name and key
- if a secret must be created manually, check in only the contract or placeholder manifest needed for deployment
- document the creation step without embedding live secret material

Treat any token, password, API key, or private endpoint in `values.yaml` as a likely mistake until proven otherwise.

7. Add companion manifests deliberately.

Charts rarely fit the repo perfectly without extra manifests. Add separate manifests when the repo wants explicit control over:
- `HTTPRoute` or Gateway API objects
- service accounts and RBAC bindings
- PVCs or storage contracts
- namespace creation
- certificates, issuers, or external secrets wiring

Prefer disabling chart-managed versions of those resources in `values.yaml` when the repo manages them separately.

8. Confirm Argo CD will pick it up.

Check that the new component path fits the existing ApplicationSet patterns for its top-level area and will therefore be rendered through the repo's `kustomize-build-with-helm` plugin. If the path is outside the existing generator coverage, update the appropriate ApplicationSet manifest so Argo CD will manage the component.

Relevant repo anchors:
- `infrastructure/infrastructure-components-appset.yaml`
- `services/services-appset.yaml`
- `applications/applications-appset.yaml`

9. Document only the operational residue.

If the install requires information that cannot live cleanly in manifests, update an existing doc or add a focused new one.

Document things like:
- secret creation commands
- external dependencies
- access URLs
- manual bootstrap or post-install steps
- upgrade notes
- troubleshooting details another operator would need later

Prefer an existing component `README.md` or a topical page under `docs/`. Keep it concise and actionable.

10. Validate the rendered result before finishing.

Validate the component with Kustomize and, when useful, Helm rendering:
- build the component with Kustomize Helm enabled
- confirm the chart resolves correctly
- verify companion manifests and namespace wiring appear in the output
- confirm any important values overrides are reflected in the rendered manifests
- if the chart includes CRDs, verify they are rendered only when intended

Useful checks may include:
- `kubectl kustomize <component-path> --enable-helm`
- `kustomize build <component-path> --enable-helm`
- `helm template <release-name> <repo>/<chart> --version <version> -f <component-path>/values.yaml`

11. Conclude with the declared source of truth.

State:
- where the component was added
- which chart and version were pinned
- which resources are managed by the chart versus separate manifests
- whether any manual secret or bootstrap steps remain
- what validation was run

## Decision Points

- If the chart can manage a resource but the repo already manages that concern explicitly, prefer repo-managed companion manifests.
- If the chart requires large or fragile overrides, reconsider whether the chart is a good fit before proceeding.
- If documentation would only repeat what the manifests already declare, do not add it.
- If the correct top-level folder is ambiguous, stop and get confirmation before spreading manifests across the repo.
- If the chart version is not the latest upstream release, document why the repo is intentionally pinning older.

## Completion Checks

The install is complete when:
- the component is placed in the correct repo area
- `kustomization.yaml` uses `helmCharts`
- `values.yaml` is minimal and contains no live secrets
- required companion manifests are present beside the chart config
- Argo CD can discover the component through the existing ApplicationSet layout
- any necessary operator-facing documentation is updated
- the rendered output validates successfully

## Repo Examples

- `infrastructure/monitoring/grafana` shows a chart installed through `helmCharts` with a local `values.yaml`
- `services/headlamp` shows a chart-backed service with separate repo-managed RBAC and access resources

## Response Pattern

When using this skill, structure the work as:
1. identify the correct repo location
2. verify the upstream chart and version
3. create or update `kustomization.yaml`, `values.yaml`, and companion manifests
4. document any residual manual steps
5. validate the rendered result
6. summarize what is now Git-managed and what still requires operator action