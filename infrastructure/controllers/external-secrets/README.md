# External Secrets

This component installs the External Secrets Operator from the Helm chart declared in [kustomization.yaml](kustomization.yaml).

The chart installation is Git-managed. Provider credentials are not.

Before syncing any `SecretStore`, `ClusterSecretStore`, or `ExternalSecret` resources that depend on provider credentials, create the required Kubernetes secret in the `external-secrets` namespace and reference it from your store manifests.

## Infisical (Universal Auth)

The checked-in [infisical-cluster-secret-store.yaml](infisical-cluster-secret-store.yaml) file configures an Infisical `ClusterSecretStore` using Universal Auth as described in the [external-secrets Infisical provider docs](https://external-secrets.io/latest/provider/infisical/#universal-auth).

The store reads credentials from a Kubernetes secret named `infisical-universal-auth` in the `external-secrets` namespace. Create that secret before syncing the store:

```sh
kubectl create namespace external-secrets

kubectl create secret generic infisical-universal-auth \
  -n external-secrets \
  --from-literal=clientId='<your-infisical-client-id>' \
  --from-literal=clientSecret='<your-infisical-client-secret>'
```

Obtain the Client ID and Client Secret from the Infisical dashboard under Access Control > Machine Identities > Universal Auth.

Once the secret exists, sync the `external-secrets` Argo CD application. The `ClusterSecretStore` can then become `Ready` and any `ExternalSecret` resources that reference `infisical` can begin pulling secrets from Infisical.

The `hostAPI` in [infisical-cluster-secret-store.yaml](infisical-cluster-secret-store.yaml) defaults to `https://app.infisical.com/api` for Infisical Cloud. Update it to your own base URL, such as `https://infisical.example.com/api`, if you are running a self-hosted instance.

Do not put provider credentials in [values.yaml](values.yaml).