# External Secrets

This component installs the External Secrets Operator from the Helm chart declared in [kustomization.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/controllers/external-secrets/kustomization.yaml).

The chart installation is Git-managed. Provider credentials are not.

Before syncing any `SecretStore`, `ClusterSecretStore`, or `ExternalSecret` resources that depend on provider credentials, create the required Kubernetes secret in the `external-secrets` namespace and reference it from your store manifests.

Example bootstrap flow:

```powershell
kubectl create namespace external-secrets

kubectl create secret generic <provider-auth-secret> `
  -n external-secrets `
  --from-literal=<key1>='<value1>' `
  --from-literal=<key2>='<value2>'
```

Then add provider-specific `SecretStore` or `ClusterSecretStore` manifests to the repo so Argo CD manages the contract in Git.

Do not put provider credentials in [values.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/controllers/external-secrets/values.yaml).
