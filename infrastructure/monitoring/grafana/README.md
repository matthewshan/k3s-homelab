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

No extra pod log processing stages are currently defined in repo, with one exception: Kubernetes health-probe noise from the `temporal` namespace is dropped before Loki ingestion. Temporal's HTTP access logger (Echo framework) records every `/healthz` probe from `kube-probe` at error level even though the request succeeds (HTTP 200, empty error field). A `stage.match` drop rule in `podLogs.extraLogProcessingStages` suppresses those lines; all other Temporal logs remain visible.

Cluster metrics and cluster events intentionally exclude the `argocd`, `longhorn-system`, and `twingate` namespaces, and Kepler stays disabled to avoid spending Grafana Cloud active-series budget on energy telemetry.
