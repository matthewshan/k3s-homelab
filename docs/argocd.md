# Argo CD

## Diff customizations

- Argo CD system-level diff ignores live in `infrastructure/controllers/argocd/values.yaml` under `configs.cm.resource.customizations.ignoreDifferences.*`.
- The `twingateresourceaccesses.twingate.com` CRD ignores `.spec.versions[]?.schema.openAPIV3Schema.properties.spec.oneOf[]?.properties`.
- This avoids persistent drift when the API server normalizes an omitted schema field to `properties: null` for the Twingate CRD.
- Keep this rule scoped to the specific CRD name unless additional CRDs show the same normalization behavior.
