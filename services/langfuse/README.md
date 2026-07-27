# Langfuse

LLM observability (tracing, evaluations, datasets) for the ADK agents. This component
installs the Langfuse Helm chart through Kustomize:

- `langfuse` `1.5.40` (appVersion `3.221.1`) from `https://langfuse.github.io/langfuse-k8s`

Langfuse v3 requires four stateful backends. This deployment reuses the shared
PostgreSQL infrastructure component and bundles the other three:

| Backend | Source | Notes |
|---|---|---|
| PostgreSQL | shared `infrastructure/storage/postgresql` | metadata only — traces do not live here |
| ClickHouse | bundled subchart | trace store, the heavy dependency |
| Valkey (`redis:` alias) | bundled subchart | queue/cache |
| MinIO (`s3:` alias) | bundled subchart | event/blob storage, bucket `langfuse` auto-created |

## Footprint

Deliberately sized for a single-node homelab, **not** for production retention. The
chart's own defaults are far larger — ClickHouse alone defaults to `replicaCount: 3` at
`resourcesPreset: 2xlarge` (1 CPU / 3Gi each) plus a 3-replica ZooKeeper, which will
never schedule on this node.

| Workload | Kind | CPU req | Mem req | Volume |
|---|---|---|---|---|
| `langfuse-web` | Deployment | 100m | 512Mi | — |
| `langfuse-worker` | Deployment | 100m | 512Mi | — |
| `langfuse-clickhouse-shard0` | StatefulSet | 100m | 768Mi | 8Gi longhorn |
| `langfuse-s3` | Deployment | 50m | 256Mi | 8Gi longhorn |
| `langfuse-redis-primary` | StatefulSet | 25m | 128Mi | 2Gi longhorn |
| **Total** | **5 pods** | **375m** | **2176Mi** | |

Two gotchas encoded in `values.yaml`:

- Bitnami subcharts ignore an explicit `resources:` block unless `resourcesPreset: none`
  is also set.
- `clickhouse.clusterEnabled` **must** be `false` when `replicaCount` is `1`, and
  `zookeeper`/`keeper` are disabled with it (saves 3 pods).

Bump ClickHouse memory and the PVC sizes before trace volume grows.

## Dependencies

Make sure these are healthy before syncing this component:

- the `external-secrets` infrastructure component
- the shared PostgreSQL component at `infrastructure/storage/postgresql`

**PostgreSQL and ClickHouse must run in UTC** or Langfuse queries return wrong or empty
results. The shared instance sets no `TZ`, so the Bitnami UTC default applies — verified
with `SHOW timezone;` → `GMT`.

## Infisical keys

This service expects these keys in the `k3s-homelab` project, `lab` environment:

| Key | Purpose |
|---|---|
| `langfuse-postgres-user-password` | the `langfuse` PostgreSQL application user |
| `langfuse-nextauth-secret` | NextAuth session signing |
| `langfuse-salt` | API-key hashing salt |
| `langfuse-encryption-key` | 32-byte hex; encrypts stored LLM API keys |
| `langfuse-clickhouse-password` | bundled ClickHouse |
| `langfuse-redis-password` | bundled Valkey |
| `langfuse-minio-root-user` | bundled MinIO (value: `minio`) |
| `langfuse-minio-root-password` | bundled MinIO |

`postgres-admin-password` (already present, shared with `infrastructure/storage/postgresql`)
is also mapped in — see below.

Generate the random values with:

```sh
openssl rand -hex 32   # encryption-key — must be exactly 32 bytes hex
openssl rand -base64 32 # nextauth-secret, salt, and the three passwords
```

> Rotating `langfuse-encryption-key` orphans every LLM API key already stored in
> Langfuse. Set it once.

`external-secret.yaml` maps those into the `langfuse-secrets` Secret as
`postgres-password`, `postgres-admin-password`, `nextauth-secret`, `salt`,
`encryption-key`, `clickhouse-password`, `redis-password`, `minio-root-user`, and
`minio-root-password`.

## Database provisioning

The shared PostgreSQL PVC already exists, so that component's `primary.initdb.scripts`
never replays — it cannot create the `langfuse` role or database. `postgres-provision-job.yaml`
(sync wave `-1`) does it instead: it connects as the `postgres` superuser and idempotently
creates the role and the `langfuse` database, re-applying the password on every run so a
rotation in Infisical propagates.

This is why `langfuse-secrets` carries `postgres-admin-password`. It is read **only** by
that Job; Langfuse itself connects as the unprivileged `langfuse` user.

Note the chart's default database name is `postgres_langfuse`, not `langfuse` — the Job
and `postgresql.auth.database` must agree, and both are pinned to `langfuse` here.

Unlike `services/temporal`, the `langfuse` user password is **not** added to the
`postgresql-auth` Secret. That Secret only feeds the Bitnami chart's single
`auth.username` bootstrap (`temporal`); a second application user there would be dead
config, since this component provisions its own user and sources the credential directly.

## Operational notes

- The UI is exposed internally at `https://langfuse.mattshan.dev` through
  `gateway-internal`; TLS comes from the wildcard `cert-mattshandev`, remote access via
  Twingate. The chart's own Ingress is disabled in favour of the repo-managed HTTPRoute.
- In-cluster endpoint for agents: Service `langfuse-web` on port `3000`. The OTLP trace
  endpoint is `/api/public/otel` with HTTP Basic auth (`public_key:secret_key`).
- A `secret-ready-gate` Job in sync wave `-1` blocks chart resources until
  `ExternalSecret/langfuse-secrets` is Ready and the Secret exists. Argo CD replaces both
  wave `-1` Jobs on retry, and finished runs are cleaned up after 5 minutes.
- The chart's bundled NetworkPolicies restrict ClickHouse/Valkey/MinIO to their service
  ports but set no source selector, so they do not need gateway exceptions.
- **First login:** browse the UI, create an account (the first user is the owner), then
  create an organization and project, and mint public + secret API keys under
  *Project → Settings → API Keys*. Those feed the `daily-briefing` deployment's
  `LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY`. Consider setting
  `langfuse.additionalEnv` `AUTH_DISABLE_SIGNUP=true` after the owner account exists.
- Schema migrations run automatically on the `langfuse-web` pod at startup
  (`LANGFUSE_AUTO_POSTGRES_MIGRATION_DISABLED=false`), so the first sync takes a few
  minutes and ClickHouse must be Ready before web reports healthy.
