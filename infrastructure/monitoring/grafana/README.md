# Grafana k8s Monitoring

This component deploys the Grafana `k8s-monitoring` Helm chart from [kustomization.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/monitoring/grafana/kustomization.yaml) using the values in [values.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/monitoring/grafana/values.yaml).

Before Argo CD syncs the `grafana` infrastructure application, create the required secret in the `monitoring` namespace.

Required secret:

- `grafana-cloud-auth-grafana-k8s-monitoring` with keys `metricsUsername`, `logsUsername`, `otlpUsername`, and `password`

Key usage:

- `metricsUsername` is used by the Prometheus remote_write destination.
- `logsUsername` is used by the Loki destination.
- `otlpUsername` is used by the OTLP destination and all Alloy remote configuration clients.
- `password` is shared across all of them.

Example bootstrap commands:

```bash
kubectl create namespace monitoring

kubectl create secret generic grafana-cloud-auth-grafana-k8s-monitoring -n monitoring \
  --from-literal=metricsUsername="<metrics-username>" \
  --from-literal=logsUsername="<logs-username>" \
  --from-literal=otlpUsername="<otlp-username>" \
  --from-literal=password="<grafana-cloud-api-key>"
```

After the secrets exist, refresh the `infrastructure-components` ApplicationSet or let Argo CD reconcile normally.

This repo intentionally manages the Alloy logs collector configuration locally so targeted pod log filters can be declared in [infrastructure/monitoring/grafana/alloy/pod-logs-extra-processing.alloy](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/monitoring/grafana/alloy/pod-logs-extra-processing.alloy). `alloy-logs.remoteConfig.enabled` stays disabled so Git remains authoritative for log filtering.

[infrastructure/monitoring/grafana/values.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/monitoring/grafana/values.yaml) is generated from that file for the `podLogs.extraLogProcessingStages` value. Refresh it with:

```powershell
./scripts/sync-grafana-alloy-log-filters.ps1
```

To lint the source fragment directly before syncing, run:

```powershell
./scripts/lint-grafana-alloy-log-filters.ps1
```

The current local log processing rules:

- drop the known Longhorn `csi-snapshotter` missing `VolumeSnapshot*` watch noise before it is shipped to Grafana Loki
- sample Twingate `homelab-connector` `established_connection` analytics lines at 10% so high-volume access noise is reduced without losing the log stream entirely

The Twingate sampling rule uses a namespace-scoped match, extracts the JSON payload from `ANALYTICS` log lines, and then samples only entries where `connector.name` is `homelab-connector` and `event_type` is `established_connection`. This avoids brittle inline LogQL regex escaping in `stage.match` selectors.

To validate the rendered Alloy logs pipeline before syncing, run:

```powershell
./scripts/sync-grafana-alloy-log-filters.ps1

$rendered = helm template grafana-k8s-monitoring grafana/k8s-monitoring --version 3.8.1 -f ./infrastructure/monitoring/grafana/values.yaml
$configDoc = ($rendered -join "`n") -split "(?m)^---\s*$" | Where-Object {
  $_ -match '(?m)^kind:\s+ConfigMap\s*$' -and $_ -match '(?m)^\s+name:\s+grafana-k8s-monitoring-alloy-logs\s*$' -and $_ -match '(?m)^\s+config\.alloy:\s+\|\s*$'
} | Select-Object -First 1
$config = foreach ($line in ($configDoc -split "`r?`n")) {
  if ($line -match '^    ') { $line.Substring(4) }
}
$config | Set-Content ./tmp-grafana-alloy-logs.config.alloy
alloy validate ./tmp-grafana-alloy-logs.config.alloy
```

The source file [infrastructure/monitoring/grafana/alloy/pod-logs-extra-processing.alloy](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/monitoring/grafana/alloy/pod-logs-extra-processing.alloy) is only a stage fragment. `./scripts/lint-grafana-alloy-log-filters.ps1` wraps the current fragment in memory with a minimal `loki.process` and `loki.write` config, writes a temporary validation file, runs `alloy validate`, and removes the temp file afterward.
