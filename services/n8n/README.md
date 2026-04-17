# n8n

Before syncing or starting the n8n deployment, make sure the `external-secrets` infrastructure component is healthy and Infisical contains the required source key `n8n-encryption-key`.

Required Kubernetes secret contract:

- Name: `n8n-secret`
- Namespace: `n8n`
- Key: `N8N_ENCRYPTION_KEY`

This directory now includes an `ExternalSecret` that creates `n8n-secret` from Infisical.

The deployment in this folder still expects that secret to exist before the pod starts; the difference is that the secret should now be reconciled by External Secrets rather than created manually.
