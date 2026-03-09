---
name: grafana-log-filtering
description: 'Suppress noisy Kubernetes logs before they are sent to Grafana Loki. Use for Grafana k8s-monitoring, Alloy pod log filters, Longhorn log noise, repo-managed GitOps log filtering, deciding when Grafana Fleet remote config must be overridden, and validating targeted drop rules in this homelab repo.'
argument-hint: 'What log line should be suppressed, which namespace or container emits it, and what repo-managed filter should be added?'
user-invocable: true
---

# Grafana Log Filtering

Use this skill when a Kubernetes workload is generating noisy logs that should be dropped before they reach Grafana Loki.

This repository ships logs through the Grafana `k8s-monitoring` Helm chart in `infrastructure/monitoring/grafana`. Pod log collection is enabled in `values.yaml`. Treat repo-managed Helm values as the source of truth for log filtering, and use Grafana Fleet remote configuration only when the user explicitly wants out-of-band control.

## When to Use

- A known benign error is flooding Grafana logs.
- A controller emits repeated watch, retry, or reflector errors that are expected in this cluster.
- Log ingestion cost or signal-to-noise needs improvement.
- You need to add a Git-tracked filter without creating drift from the repo.
- You need to decide whether existing Grafana Fleet remote config must be disabled for `alloy-logs` so the repo becomes authoritative.

## Filtering Rules

- Prefer fixing the root cause if the log indicates a real cluster problem.
- Only suppress logs that are understood and intentionally tolerated.
- Prefer targeted filters by namespace, container, and message pattern.
- Do not drop an entire namespace unless the user explicitly wants that tradeoff.
- Prefer repo-managed filters in `values.yaml`.
- If Alloy logs remote config is enabled, disable it for `alloy-logs` when the goal is GitOps ownership.
- Use Fleet only when the user explicitly wants log filtering managed outside the repo.
- Validate the rendered chart so the filter is confirmed in the generated Alloy pipeline.

## Procedure

1. Confirm the log should be suppressed.

Capture:
- the exact message text or a safe regex fragment
- the namespace and container producing it
- whether the message is benign noise or evidence of a real fault

If the message indicates an unresolved cluster problem, stop and troubleshoot the root cause instead of filtering it.

2. Identify where Grafana log processing is controlled.

Inspect:
- `infrastructure/monitoring/grafana/values.yaml`
- whether `podLogs.enabled` is true
- whether `alloy-logs.remoteConfig.enabled` is true

Decision:
- If `alloy-logs.remoteConfig.enabled: true`, Grafana Fleet may override local log pipeline settings.
- For this repo, prefer setting `alloy-logs.remoteConfig.enabled: false` so Git remains authoritative for logs.
- Only keep Fleet authoritative when the user explicitly asks for out-of-band log management.

3. Add the narrowest viable filter.

For repo-managed pod log filters, prefer `podLogs.extraLogProcessingStages` with a `stage.match` block.

Pattern guidance:
- match on `namespace`
- match on `container` when possible
- match on the exact noisy line with a regex
- set a specific `drop_counter_reason`

Example pattern:

```alloy
stage.match {
  selector = "{namespace=\"longhorn-system\", container=\"csi-snapshotter\"} |~ \"Failed to watch.*(VolumeSnapshotClass|VolumeSnapshotContent)\""
  action = "drop"
  drop_counter_reason = "longhorn_snapshot_api_noise"
}
```

Broader fallback options, in descending order of safety:
- drop a single message pattern from one container
- drop all logs from one container
- exclude a namespace only if the user accepts losing all logs from it

4. Keep repo documentation aligned.

If the repo intentionally manages Alloy log filters locally, note that in the Grafana component README so future operators understand why remote config is disabled for logs.

Relevant repo files:
- `infrastructure/monitoring/grafana/values.yaml`
- `infrastructure/monitoring/grafana/README.md`
- `infrastructure/monitoring/grafana/kustomization.yaml`

5. Validate before applying.

Render the chart and confirm the filter appears in the generated Alloy config.

Suggested validation:
- `helm template grafana-k8s-monitoring grafana/k8s-monitoring --version 3.8.1 -f infrastructure/monitoring/grafana/values.yaml`
- search the rendered output for the `stage.match` selector or `drop_counter_reason`

6. Conclude with the operational impact.

State:
- which log line will be dropped
- that the filter is managed in repo Helm values unless otherwise requested
- whether `alloy-logs.remoteConfig.enabled` was changed
- what signal remains visible after the filter is applied

## Completion Checks

The filtering pass is complete when:
- the noisy log source is explicitly identified
- the filter targets a narrow namespace or container plus message pattern
- GitOps ownership of the filter is explicit, unless the user intentionally chose Fleet
- the rendered chart includes the expected drop rule
- documentation reflects any intentional local ownership of Alloy log filtering

## Repo-Specific Notes

- Grafana monitoring lives in `infrastructure/monitoring/grafana`.
- The chart version should stay aligned with `infrastructure/monitoring/grafana/kustomization.yaml`.
- In this repo, a known example is suppressing the Longhorn `csi-snapshotter` missing `VolumeSnapshot*` watch noise before Loki ingestion.