# n8n

Create the runtime secret before syncing or starting the n8n deployment.

Required secret:

- Name: `n8n-secret`
- Namespace: `n8n`
- Key: `N8N_ENCRYPTION_KEY`

Example:

```powershell
kubectl create namespace n8n
kubectl create secret generic n8n-secret `
  -n n8n `
  --from-literal=N8N_ENCRYPTION_KEY='<replace-with-a-long-random-string>'
```

If the namespace already exists, run only the secret command.

Generate a strong key with PowerShell:

```powershell
[Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }))
```

The deployment in this folder expects that secret to exist before the pod starts.