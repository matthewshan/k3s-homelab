# n8n

## Secret provisioning via Infisical

The `n8n-secret` is managed by an `ExternalSecret` in [n8n-secret-externalsecret.yaml](n8n-secret-externalsecret.yaml). External Secrets pulls the value from Infisical and creates the Kubernetes secret automatically.

Before syncing this component, seed the following key into the Infisical project **`k3s-homelab`**, environment **`lab`**:

| Infisical key | Kubernetes key | Description |
|---|---|---|
| `N8N_ENCRYPTION_KEY` | `N8N_ENCRYPTION_KEY` | Long random string used to encrypt n8n credentials |

The External Secrets bootstrap prerequisite (`infisical-universal-auth` in `external-secrets`) must exist before the `ClusterSecretStore` can become ready. See [infrastructure/controllers/external-secrets/README.md](../../infrastructure/controllers/external-secrets/README.md) for setup instructions.

Generate a strong key with PowerShell before seeding it into Infisical:

```powershell
[Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }))
```

Or with bash:

```bash
openssl rand -base64 32
```

The deployment in this folder expects that secret to exist before the pod starts.