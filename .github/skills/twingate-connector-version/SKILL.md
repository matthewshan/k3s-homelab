---
name: twingate-connector-version
description: 'Update Twingate connector version in this homelab repo. Use for prompts like "update twingate connector version", "bump twin gate connector tag", "pin Twingate connector 1.88.0", or decide whether connector updates should use spec.image or spec.imagePolicy.'
argument-hint: 'What connector version should be used, and do you want an explicit Git pin or operator-managed auto-updates?'
user-invocable: true
---

# Manage Twingate Connector Version

Use this skill when changing the Twingate connector runtime version in this repository.

This repo installs the Twingate operator chart through `infrastructure/networking/twingate/kustomization.yaml`, but the connector runtime is managed separately through the `TwingateConnector` custom resource in `infrastructure/networking/twingate/connector.yaml`.

For this homelab, prefer Git-tracked connector version changes in the connector manifest. Do not assume a Helm chart bump updates the connector image.

## When to Use

- The user asks to update Twingate connector version.
- The user asks to bump or pin the Twingate connector tag.
- The user asks whether the Twingate Helm chart also updates the connector.
- The user wants to switch between explicit connector pinning and `imagePolicy` auto-updates.
- The user wants supporting evidence from upstream docs before changing the connector version.

## Core Rules

- Treat the operator chart version and the connector runtime version as separate concerns.
- The operator chart lives in `infrastructure/networking/twingate/kustomization.yaml`.
- The connector runtime lives in `infrastructure/networking/twingate/connector.yaml`.
- `TwingateConnector.spec.image` is the upstream field for an explicit connector image pin.
- `TwingateConnector.spec.imagePolicy` is the upstream field for scheduled connector auto-updates.
- Never set both `spec.image` and `spec.imagePolicy` at the same time. The CRD forbids that combination.
- In this Argo CD-managed repo, prefer `spec.image.tag` when the user asks for a specific connector version so the desired version stays explicit in Git.
- Only switch to `imagePolicy` when the user explicitly wants the operator to keep connectors updated automatically.
- If the user asks only for a connector version change, do not change the operator chart unless they also asked for an operator upgrade.

## Evidence To Check

When the user wants proof before editing, use these upstream sources:

- Twingate operator repo: https://github.com/Twingate/kubernetes-operator
- Helm chart OCI package: https://ghcr.io/twingate/helmcharts/twingate-operator
- API reference for explicit image pinning: https://github.com/Twingate/kubernetes-operator/wiki/API-Reference#twingateconnectorspecimage
- API reference for scheduled auto-updates: https://github.com/Twingate/kubernetes-operator/wiki/API-Reference#twingateconnectorspecimagepolicy
- Getting Started example showing `imagePolicy` for automatic connector updates: https://github.com/Twingate/kubernetes-operator/wiki/Getting-Started#deploy-a-connector-to-connect-your-cluster-to-twingate

Useful local checks:

- `helm show values oci://ghcr.io/twingate/helmcharts/twingate-operator --version <chart-version>`
- `helm template twingate-operator oci://ghcr.io/twingate/helmcharts/twingate-operator --version <chart-version> --namespace twingate --values infrastructure/networking/twingate/values.yaml --include-crds`
- inspect the rendered output for the operator deployment image and the shipped `TwingateConnector` CRD fields

## Procedure

1. Clarify the requested outcome.

Decide whether the user wants:
- only a connector runtime bump
- an operator chart bump
- both
- or a strategy change from explicit pinning to auto-updates

If the ask is just "update twingate connector version", default to changing the connector resource, not the chart.

2. Verify the upstream control point.

Confirm that:
- the chart controls the operator deployment image
- the connector runtime is controlled through `TwingateConnector`
- the CRD allows either `spec.image` or `spec.imagePolicy`

If the user asked for evidence, cite the upstream API reference and, when useful, show `helm template` output proving the chart renders the operator deployment separately from the connector CRD.

3. Update the repo source of truth.

For an explicit pin, edit `infrastructure/networking/twingate/connector.yaml` to include:

```yaml
spec:
  name: homelab-connector
  image:
    repository: twingate/connector
    tag: "1.88.0"
```

Replace the tag with the requested version.

If `imagePolicy` already exists, remove it when pinning with `spec.image`.

4. Use `imagePolicy` only when the user wants auto-updates.

For operator-managed updates, replace `spec.image` with something like:

```yaml
spec:
  name: homelab-connector
  imagePolicy:
    provider: dockerhub
    schedule: "0 0 * * *"
    version: "^1.88.0"
```

Guidance:
- `provider: dockerhub` follows the upstream example
- `schedule` controls how often the operator checks for updates
- `version` should constrain the acceptable semver range when the user does not want completely unconstrained upgrades

If the user chooses `imagePolicy`, explain that connector rollouts are then no longer tied to explicit Git commits for each tag change.

5. Keep the operator chart separate.

Only edit `infrastructure/networking/twingate/kustomization.yaml` when the user also wants the operator upgraded.

If the chart changes:
- verify the chart version upstream first
- review CRD changes because Helm does not automatically update existing CRDs on upgrade

6. Update repo docs when the strategy changes.

If you change connector version management behavior, update:
- `infrastructure/networking/twingate/README.md`
- `docs/networking.md`

Document whether the repo now:
- pins the connector image tag explicitly in Git
- or uses `imagePolicy` for operator-managed updates

Keep the note short and operational.

7. Validate with the cheapest reliable checks.

Prefer:
- `kubectl create --dry-run=client --validate=false -f infrastructure/networking/twingate/connector.yaml -o yaml`

If the chart also changed, validate that separately with:
- `helm template twingate-operator oci://ghcr.io/twingate/helmcharts/twingate-operator --version <chart-version> --namespace twingate --values infrastructure/networking/twingate/values.yaml --include-crds`

Repo-specific validation caveat:
- on this Windows setup, `kustomize build --enable-helm` may fail because the local Kustomize-to-Helm integration calls `helm version -c --short`, which is incompatible with the installed Helm version
- when that happens, use direct `helm template` as the fallback validation path

8. Conclude precisely.

State:
- which file now controls the connector version
- the connector tag or `imagePolicy` that was set
- whether the operator chart was changed or intentionally left alone
- what validation was run
- what remains to be applied or synced in Argo CD

## Repo Anchors

- `infrastructure/networking/twingate/connector.yaml`
- `infrastructure/networking/twingate/kustomization.yaml`
- `infrastructure/networking/twingate/values.yaml`
- `infrastructure/networking/twingate/README.md`
- `docs/networking.md`

## Decision Guide

- Use `spec.image.tag` when the user wants a known connector version such as `1.88.0`.
- Use `spec.imagePolicy` when the user explicitly wants automatic connector updates.
- Do not rely on the Helm chart version to imply connector image updates.
- Do not change both the connector strategy and operator chart unless the user asked for both.

## Completion Checks

The task is complete when:
- the connector version control point is identified correctly
- the manifest uses either `spec.image` or `spec.imagePolicy`, but not both
- any related docs reflect the chosen strategy
- validation confirms the edited manifest shape
- the summary clearly distinguishes connector version changes from operator chart changes