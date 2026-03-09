# Temporal

This service deploys Temporal with the upstream Helm chart and exposes the web UI at `https://temporal.mattshan.dev` through the internal gateway.

Before syncing this app, update `values.yaml` to point at your PostgreSQL host and user, then create the required password secret.

Prerequisites:

- A reachable PostgreSQL instance for Temporal persistence.
- Two existing databases: `temporal` and `temporal_visibility`.
- A database user with permission to manage schema objects in both databases.

Required secret:

- Name: `temporal-postgres`
- Namespace: `temporal`
- Key: `password`

Example:

```powershell
kubectl create namespace temporal
kubectl create secret generic temporal-postgres `
  -n temporal `
  --from-literal=password='<replace-with-your-postgres-password>'
```

If the namespace already exists, run only the secret command.

After updating `values.yaml` and creating the secret, refresh the `services` ApplicationSet or let Argo CD reconcile normally.
