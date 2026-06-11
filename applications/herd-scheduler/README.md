# Herd Scheduler

[Herd Scheduler](https://github.com/matthewshan/herd-scheduler) — group
scheduling polls — at `https://herd.mattshan.dev` (public via the Cloudflare
Tunnel wildcard → `gateway-external`). Images are published to ghcr.io by
that repo's CI; deployment contract details live in its `docs/deployment.md`.

## Database

PostgreSQL on the LAN Postgres VM (provisioned by
[`ansible/postgres-vm`](../../ansible/postgres-vm/README.md)), reached
directly via the `DATABASE_URL` secret — no in-cluster database. This is
intentionally **not** the shared in-cluster `postgresql` component: the app's
data outlives cluster rebuilds.

## Sync order

Wave-gated (same pattern as temporal's secret-ready-gate): namespace (−2) →
`ExternalSecret` (−1) → **migrate Job** (0, `Force=true,Replace=true` since
Jobs are immutable; runs `prisma migrate deploy` to completion) → app
Deployment/Service/HTTPRoute (1). A failed migration blocks the rollout.

## Secrets (Infisical)

Create these keys before first sync:

| Infisical key | Becomes env | Notes |
|---|---|---|
| `herd-scheduler-database-url` | `DATABASE_URL` | `postgresql://herd:<password>@<vm-ip>:5432/scheduler` |
| `herd-scheduler-auth-secret` | `AUTH_SECRET` | `openssl rand -base64 32` |
| `herd-scheduler-google-client-id` | `GOOGLE_CLIENT_ID` | Google Cloud Console OAuth client |
| `herd-scheduler-google-client-secret` | `GOOGLE_CLIENT_SECRET` | |
| `herd-scheduler-owner-email` | `OWNER_EMAIL` | Bootstrap owner/admin (kept out of this public repo) |

Non-secret config (`AUTH_URL`, `AUTH_TRUST_HOST`, `ALLOWLIST_ENABLED`,
`APP_TIMEZONE`) rides on the Deployment env.

## First-deploy checklist

1. ghcr packages `herd-scheduler` / `herd-scheduler` (`-migrate` tags) must be
   **public** (or add an `imagePullSecret`) — they're created on the first CI
   publish from the app repo's `main`.
2. Infisical keys above created.
3. Postgres VM up with the `scheduler` DB + `herd` role (the Ansible playbook
   does this) and reachable from the k3s node.
4. In Google Cloud Console, add the authorized redirect URI
   `https://herd.mattshan.dev/api/auth/callback/google`.
5. Cloudflare DNS: `herd.mattshan.dev` CNAME to the tunnel (covered by the
   existing `*.mattshan.dev` route in `cloudflared/config.yaml`).
