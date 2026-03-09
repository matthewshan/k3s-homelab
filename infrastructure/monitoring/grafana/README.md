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

This repo intentionally manages the Alloy logs collector configuration locally so targeted pod log filters can be declared in [values.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/monitoring/grafana/values.yaml). The current filter drops the known Longhorn `csi-snapshotter` missing `VolumeSnapshot*` watch noise before it is shipped to Grafana Loki.
