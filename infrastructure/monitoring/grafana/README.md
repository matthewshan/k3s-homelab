# Grafana k8s Monitoring

This component deploys the Grafana `k8s-monitoring` Helm chart from [kustomization.yaml](kustomization.yaml) using the values in [values.yaml](values.yaml).

## Secret provisioning via Infisical

The `grafana-cloud-auth-grafana-k8s-monitoring` secret is managed by an `ExternalSecret` in [grafana-cloud-auth-externalsecret.yaml](grafana-cloud-auth-externalsecret.yaml). External Secrets pulls the values from Infisical and creates the Kubernetes secret automatically.

Before syncing this component, seed the following keys into the Infisical project **`k3s-homelab`**, environment **`lab`**:

| Infisical key | Kubernetes key | Description |
|---|---|---|
| `metrics-username` | `metricsUsername` | Prometheus remote_write username |
| `logs-username` | `logsUsername` | Loki destination username |
| `otlp-username` | `otlpUsername` | OTLP destination and Alloy remote config username |
| `password` | `password` | Shared Grafana Cloud API key for all destinations |

The External Secrets bootstrap prerequisite (`infisical-universal-auth` in `external-secrets`) must exist before the `ClusterSecretStore` can become ready. See [infrastructure/controllers/external-secrets/README.md](../../controllers/external-secrets/README.md) for setup instructions.

After the secrets are seeded and External Secrets reconciles, refresh the `infrastructure-components` ApplicationSet or let Argo CD reconcile normally.

No extra pod log processing stages are currently defined in repo. Pod log collection excludes the `argocd`, `longhorn-system`, and `twingate` namespaces entirely because this repo does not currently need those logs in Grafana Loki.

Cluster metrics and cluster events intentionally exclude the `argocd`, `longhorn-system`, and `twingate` namespaces, and Kepler stays disabled to avoid spending Grafana Cloud active-series budget on energy telemetry.
