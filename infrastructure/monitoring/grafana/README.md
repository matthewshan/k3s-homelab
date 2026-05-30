# Grafana k8s Monitoring

This component deploys the Grafana `k8s-monitoring` Helm chart from [kustomization.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/monitoring/grafana/kustomization.yaml) using the values in [values.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/monitoring/grafana/values.yaml).

Before Argo CD syncs this component, the `external-secrets` infrastructure component and the `infisical` `ClusterSecretStore` must already be healthy.

This component expects an `ExternalSecret` in this directory to create the required Kubernetes secret in the `monitoring` namespace from Infisical.

Required Kubernetes secret contract:

- `grafana-cloud-auth-grafana-k8s-monitoring` with keys `metricsUsername`, `logsUsername`, `otlpUsername`, and `password`

Key usage:

- `metricsUsername` is used by the Prometheus remote_write destination.
- `logsUsername` is used by the Loki destination.
- `otlpUsername` is used by the OTLP destination and all Alloy remote configuration clients.
- `password` is shared across all of them.

Infisical source keys:

- `grafana-cloud-metrics-username`
- `grafana-cloud-logs-username`
- `grafana-cloud-otlp-username`
- `grafana-cloud-password`

After those Infisical keys and the External Secrets bootstrap are in place, let Argo CD reconcile normally or refresh the `infrastructure-components` ApplicationSet.

Cluster metrics and cluster events intentionally exclude the `argocd`, `longhorn-system`, and `twingate` namespaces, and Kepler stays disabled to avoid spending Grafana Cloud active-series budget on energy telemetry.

## Pod log drop rules

Drop rules live in `podLogs.extraLogProcessingStages` and are managed in this repo (Fleet remote config is disabled for `alloy-logs`). Each `stage.match` block targets the narrowest viable selector and sets a unique `drop_counter_reason` so dropped volume is observable via the `loki_process_dropped_lines_total` metric.

Current rules:

| `drop_counter_reason` | What it drops | Why |
|---|---|---|
| `temporal_healthz_probe_noise` | `kube-probe` GETs to `/healthz` in `temporal` ns | Echo logs every probe at error level even on 200 |
| `temporal_matching_taskqueue_churn` | `Started/Stopped physicalTaskQueueManager` in `temporal` ns | Normal Temporal matching-engine task queue cache eviction |
| `cilium_agent_endpoint_churn` | INFO endpoint lifecycle chatter on `cilium-agent` | Endpoint regen / port reservation / release/remove fire constantly on Job churn; warn+ retained |
| `cilium_operator_endpoints_deprecation` | `v1 Endpoints is deprecated` WARN on `cilium-operator` | Upstream chart still uses the old API; nothing actionable here until upgrade |
| `alloy_helm_reconcile_noise` | `helm.controller` `Reconciled release` in `monitoring` | Normal Alloy operator reconcile loop |
| `alloy_tail_routine_noise` | `tail routine started/exited`, `stopped tailing file` in `monitoring` | Alloy self-logging file rotations |
| `alloy_cluster_gossip_noise` | `rejoining peers` from `service=cluster` in `monitoring` | Alloy cluster gossip heartbeat |
| `external_secrets_webhook_cert_noise` | `injecting ca certificate` / `updating webhook config` in `external-secrets` | Webhook cert rotation INFO (~5 min cadence) |
| `kube_probe_http_access_log_noise` | Any access-log line containing a `"kube-probe/X.Y"` user-agent | Kubelet probe traffic recorded as HTTP access logs; never useful signal |

Known noise not yet filtered:

- **`temporal-secret-ready-gate` Job binding events** flood the cluster-events pipeline. The k8s-monitoring 3.8.1 chart does not expose an `extraLogProcessingStages` hook for `clusterEvents`, so this cannot be filtered in repo without dropping the entire `temporal` namespace from events. Better fix is upstream: stop running the ready-gate hook on every Argo sync.

## Validating log pipeline changes

Alloy log pipeline rules live in `values.yaml` as River snippets inside `podLogs.extraLogProcessingStages`. They are opaque strings from Helm's perspective, so they must be syntax-checked before merge — past bad pushes ended up in the cluster.

The validation harness lives at the repo root:

```
task validate:monitoring
```

This renders the `k8s-monitoring` chart against `values.yaml`, extracts the generated `alloy-logs` ConfigMap, and runs `alloy fmt` on it. The task fails non-zero on any River syntax error, unknown component, or unknown argument. It is the same check run by `.github/workflows/validate-monitoring.yml` on every PR that touches this directory.

Tooling is fully containerised (`alpine/helm`, `mikefarah/yq`, `grafana/alloy`) so only `task` and `docker` are required locally; image versions are pinned in `Taskfile.yml`.

When changing a drop rule, the recommended pre-merge flow is:

1. Edit the `stage.match` block in `values.yaml`.
2. `task validate:monitoring` — gates on River syntax.
3. `task validate:monitoring:render | grep -A2 <drop_counter_reason>` — eyeball the rendered Alloy block.
4. Use `logcli` against Grafana Cloud Loki to confirm the selector and regex match the lines you actually want to drop, and *only* those lines. The same `selector` plus `|~` filter from the `stage.match` block can be pasted into `logcli query`.
5. Open the PR; CI re-runs the same task.

`alloy fmt` only catches syntax. Logic errors (a regex matching more than you intended) must be caught with the `logcli` dry-run in step 4.
