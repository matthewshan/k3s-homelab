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
- a `secret-ready-gate` Job that blocks the Temporal sync wave until `Secret/temporal-db` exists

Operational notes:

- Temporal Web is exposed internally at `https://temporal.mattshan.dev` through `gateway-internal`.
- The Temporal gRPC frontend stays cluster-internal on the `temporal-frontend` service at port `7233`.
- The shared PostgreSQL component bootstraps the `temporal` and `temporal_visibility` databases.
- If Temporal dependencies are ever split into a separate Argo CD `Application`, keep that dependency app on a lower sync wave than the main Temporal app.
- `numHistoryShards` cannot be changed in-place later. If you outgrow `4`, plan on a fresh deployment or a migration.
