---
description: "Use when adding or updating Kubernetes components that use Helm charts, kustomization.yaml, or Argo CD-managed infrastructure. Prefer Kustomize helmCharts and verify the latest chart version before changing chart-based deployments."
applyTo: "infrastructure/**/kustomization.yaml, applications/**/kustomization.yaml, services/**/kustomization.yaml"
---
# Helm Through Kustomize

- When a component is sourced from a Helm chart, prefer adding it through `kustomization.yaml` with `helmCharts` instead of checking in rendered Helm output or introducing an unrelated deployment pattern.
- Before proposing or changing a chart version, verify the latest upstream Helm chart release and use that version unless the repo already needs a pinned older version for a documented reason.
- Keep chart configuration minimal and repo-specific. Put chart-specific overrides in `values.yaml` and keep lifecycle wiring in `kustomization.yaml`.
- Match existing repo structure: namespace manifest, `kustomization.yaml`, chart values, and any companion manifests such as `HTTPRoute`, secrets, or PVCs belong beside the component.
- If chart adoption requires extra operational context, add or update documentation under `docs/` so the setup and maintenance steps are preserved in the repo.