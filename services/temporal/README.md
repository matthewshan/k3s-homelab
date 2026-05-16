# Temporal

This component installs the Temporal Helm chart through Kustomize:

- `temporal` `1.2.0` from `https://go.temporal.io/helm-charts`

Temporal now depends on the shared PostgreSQL infrastructure component in `infrastructure/storage/postgresql` instead of owning a database release directly.

The Temporal footprint stays intentionally small:

- one replica each of the Temporal frontend, history, matching, worker, and web pods
- `admintools` disabled
- `numHistoryShards` pinned to `4` for a small homelab deployment

Before syncing this component, make sure these dependencies are healthy first:

- the `external-secrets` infrastructure component
- the shared PostgreSQL component at `infrastructure/storage/postgresql`

This service also expects Infisical to contain this key:

- `postgres-temporal-user-password` for the `temporal` PostgreSQL application user

This directory includes an `ExternalSecret` that creates the `temporal-db` secret in the `temporal` namespace with these keys:

- `postgres-temporal-user-password` mapped from `postgres-temporal-user-password`

Operational notes:

- Temporal Web is exposed internally at `https://temporal.mattshan.dev` through `gateway-internal`.
- The Temporal gRPC frontend stays cluster-internal on the `temporal-frontend` service at port `7233`.
- The shared PostgreSQL component bootstraps the `temporal` and `temporal_visibility` databases.
- A `secret-ready-gate` Job in sync wave `-1` blocks Temporal chart resources until `ExternalSecret/temporal-db` is `Ready` and `Secret/temporal-db` exists.
- `numHistoryShards` cannot be changed in-place later. If you outgrow `4`, plan on a fresh deployment or a migration.
