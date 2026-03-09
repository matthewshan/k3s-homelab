---
description: "Use when editing Helm values.yaml files or chart configuration for Kubernetes services and infrastructure. Prevent committing secrets and prefer referencing pre-created Kubernetes secrets."
applyTo: "**/values.yaml"
---
# Values Secret Hygiene

- Never commit real secrets, tokens, passwords, API keys, or private endpoints into `values.yaml`.
- If a chart needs credentials, reference an existing Kubernetes `Secret` by name and key when the chart supports it.
- If a secret must be created manually, check in only the secret contract or template needed for deployment, and document the creation step without embedding live secret material.
- Treat suspicious inline values as secret candidates by default. Replace them with secret references or documented placeholders before finishing the change.
- When secret handling changes, add or update the related operational notes under `docs/` so the setup remains reproducible.