# Storage

## Shared PostgreSQL

The repo now includes a shared PostgreSQL component at `infrastructure/storage/postgresql` for non-production workloads that need a simple in-cluster database.

It currently starts with a Longhorn-backed `10Gi` PVC for the primary database pod.

The current bootstrap is still centered on Temporal as the first consumer:

- the chart creates the `temporal` PostgreSQL user
- the chart creates the `temporal` database
- an `initdb` script creates the `temporal_visibility` database on first boot

The PostgreSQL admin secret stays in the `postgresql` namespace as `postgresql-auth`. Application runtime secrets stay with their consuming app namespaces; for example, Temporal still reads its own `temporal-db` secret from the `temporal` namespace.

Important `initdb` caveat:

- Bitnami `primary.initdb.scripts` only runs when PostgreSQL initializes an empty data directory.
- If you later change the bootstrap SQL or add another app database after the PVC is already populated, those scripts will not rerun automatically.
- For that case, use manual `psql` changes or add a dedicated provisioning job.
