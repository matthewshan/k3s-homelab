# Shared PostgreSQL

This component installs the Bitnami `postgresql` Helm chart as a shared, test-grade database service in the `postgresql` namespace.

The primary database pod uses a Longhorn-backed `10Gi` PVC to start.

It is generic at the component level, but its current bootstrap is still tailored to the repo's first consumer:

- the chart creates the `temporal` PostgreSQL user
- the chart creates the `temporal` database
- an `initdb` script creates the `temporal_visibility` database on first boot

Before syncing this component, make sure the `external-secrets` infrastructure component is healthy and Infisical contains these keys:

- `postgres-temporal-user-password` for the chart-created `temporal` application user
- `postgres-admin-password` for the built-in `postgres` admin user

This directory includes an `ExternalSecret` that creates the `postgresql-auth` secret in the `postgresql` namespace with these keys:

- `postgres-temporal-user-password` mapped from `postgres-temporal-user-password`
- `postgres-password` mapped from `postgres-admin-password`

Initdb note:

- `primary.initdb.scripts` only runs when the chart initializes a fresh data directory.
- If you later add another application database or user after the PVC already exists, the chart will not replay those scripts.
- If that happens, use `psql` manually or add a dedicated provisioning job later.
