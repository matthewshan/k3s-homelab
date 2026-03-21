# External Secrets

This component installs the External Secrets Operator from the Helm chart declared in [kustomization.yaml](kustomization.yaml).

The chart installation is Git-managed. Provider credentials are not.

## Bootstrap prerequisite: one manual Kubernetes secret

The only Kubernetes secret that must be created manually is `infisical-universal-auth` in the `external-secrets` namespace. This secret holds the credentials for the Infisical provider and cannot be sourced from External Secrets itself.

Create it before syncing the `external-secrets` Argo CD application:

```sh
kubectl create namespace external-secrets

kubectl create secret generic infisical-universal-auth \
  -n external-secrets \
  --from-literal=clientId='<your-infisical-client-id>' \
  --from-literal=clientSecret='<your-infisical-client-secret>'
```

Obtain the Client ID and Client Secret from the Infisical dashboard under **Access Control > Machine Identities > Universal Auth**.

## Infisical project and environment

All `ExternalSecret` resources in this repo pull from the Infisical project **`k3s-homelab`**, environment **`lab`**, as configured in [infisical-cluster-secret-store.yaml](infisical-cluster-secret-store.yaml).

Before syncing any component that creates an `ExternalSecret`, seed the corresponding runtime secrets into Infisical. The required keys for each component are listed in the table below. Seed all of them into the `k3s-homelab / lab` environment in Infisical before triggering a full sync.

| Infisical key | Kubernetes namespace | Kubernetes secret name | Kubernetes key |
|---|---|---|---|
| `api-token` | `cert-manager` | `cloudflare-api-token` | `api-token` |
| `email` | `cert-manager` | `cloudflare-api-token` | `email` |
| `credentials.json` | `cloudflared` | `tunnel-credentials` | `credentials.json` |
| `twingate-api-key` | `twingate` | `twingate-operator-auth` | `TWINGATE_API_KEY` |
| `twingate-remote-network-id` | `twingate` | `twingate-operator-auth` | `TWINGATE_REMOTE_NETWORK_ID` |
| `metrics-username` | `monitoring` | `grafana-cloud-auth-grafana-k8s-monitoring` | `metricsUsername` |
| `logs-username` | `monitoring` | `grafana-cloud-auth-grafana-k8s-monitoring` | `logsUsername` |
| `otlp-username` | `monitoring` | `grafana-cloud-auth-grafana-k8s-monitoring` | `otlpUsername` |
| `password` | `monitoring` | `grafana-cloud-auth-grafana-k8s-monitoring` | `password` |
| `n8n-encryption-key` | `n8n` | `n8n-secret` | `N8N_ENCRYPTION_KEY` |

## Rollout order

External Secrets CRDs and controller must be running before any `ExternalSecret` object can be reconciled. The `external-secrets` and `cert-manager` applications are deployed independently by the `infrastructure-components` ApplicationSet with no guaranteed inter-application ordering. On a fresh cluster sync, an `ExternalSecret` resource in cert-manager or another namespace may fail to reconcile on the first attempt if the External Secrets CRDs are not yet installed.

The ApplicationSet is configured with `retry: limit: 5`, so Argo CD will automatically retry. Once the `external-secrets` application is Healthy and the `ClusterSecretStore` shows `Ready`, subsequent syncs will reconcile all `ExternalSecret` resources successfully.

For a clean initial rollout, sync the `external-secrets` application first and confirm it is Healthy before triggering a full sync of the remaining infrastructure components.

## Verification

After syncing:

```sh
kubectl get clustersecretstore infisical -o yaml
# Confirm Ready=True

kubectl get externalsecret -A
# Confirm all show Ready/Synced
```

## Self-hosted Infisical

The `hostAPI` in [infisical-cluster-secret-store.yaml](infisical-cluster-secret-store.yaml) defaults to `https://app.infisical.com/api` for Infisical Cloud. Update it to your own base URL, such as `https://infisical.example.com/api`, if you are running a self-hosted instance.

Do not put provider credentials in [values.yaml](values.yaml).