# Monitoring

## Grafana Alloy log filter validation

Grafana log filtering source for this repo lives in [infrastructure/monitoring/grafana/alloy/pod-logs-extra-processing.alloy](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/monitoring/grafana/alloy/pod-logs-extra-processing.alloy). [infrastructure/monitoring/grafana/values.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/monitoring/grafana/values.yaml) is generated from that file for the Helm chart input. YAML validation alone will not catch invalid `loki.process` selectors or other Alloy pipeline errors.

Refresh the generated values block with:

```powershell
./scripts/sync-grafana-alloy-log-filters.ps1
```

Validate the rendered Alloy config before syncing changes to Grafana log filters:

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

What it does:

- syncs the source Alloy filter file into the Helm values block
- renders the `k8s-monitoring` Helm chart using the version pinned in [infrastructure/monitoring/grafana/kustomization.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/monitoring/grafana/kustomization.yaml)
- extracts the generated `config.alloy` from the Alloy logs ConfigMap
- runs `alloy validate` locally against that rendered config and fails if the pipeline cannot load

Operational notes:

- the script requires `helm` and `alloy`
- the script adds the `grafana` Helm repo locally if it is missing

The source file [infrastructure/monitoring/grafana/alloy/pod-logs-extra-processing.alloy](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/monitoring/grafana/alloy/pod-logs-extra-processing.alloy) is a stage fragment, not a full standalone Alloy config. Validate the rendered config produced by Helm rather than calling `alloy validate` on the fragment directly.