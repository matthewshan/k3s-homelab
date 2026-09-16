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
- A `namespace-provision` Job in sync wave `1` registers the Temporal namespaces workers connect to. See below.

## Namespaces

Temporal namespaces live in **Temporal's own database, not in Kubernetes**, so nothing else in this repo recreates them — a cluster or PostgreSQL rebuild loses them. `namespace-provision-job.yaml` registers them on every sync so that cannot happen quietly.

Add a namespace by editing the space-separated `NAMESPACES` env var in that file; `RETENTION` sets how long closed workflows are kept. The Job is idempotent: `temporal operator namespace create` has no `--if-not-exists` and exits non-zero on an existing namespace, so it checks with `describe` first and tolerates losing a creation race.

Worth knowing if this ever looks broken:

- **A missing namespace looks like a broken Web UI, not missing state.** The UI opens on `default` and reports `Namespace default is not found`, which reads like a login or routing problem. Check `temporal operator namespace list` before debugging anything else.
- **The self-hosted Web UI cannot create namespaces** — that is a Temporal Cloud feature. The CLI or an SDK is the only way, which is why this Job exists.
- `admintools` is disabled, so there is no in-cluster CLI pod. To poke at the server by hand, port-forward `svc/temporal-frontend` and use a local `temporal` CLI. Do **not** expose the gRPC frontend through the gateway to avoid that — the server has no auth.
- The Job carries `activeDeadlineSeconds` so it always reaches a terminal state. A Job that can never finish is what wedged the Langfuse teardown: Argo CD will not run an Application's deletion finalizer while an operation is still `Running`.
- Argo CD is configured to replace that gate Job on retries, and Kubernetes cleans up finished runs after 5 minutes so failed gates do not stay stuck indefinitely.
- `numHistoryShards` cannot be changed in-place later. If you outgrow `4`, plan on a fresh deployment or a migration.
