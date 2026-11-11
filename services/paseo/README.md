# paseo

[Paseo](https://github.com/getpaseo/paseo) daemon: run Claude Code agents on
the homelab and drive them from a phone or laptop at
`https://paseo.mattshan.dev` (internal via `gateway-internal`, reached from
outside over the Twingate `apps` resource). Agents use the Claude **Pro** plan
through `CLAUDE_CODE_OAUTH_TOKEN`; no Anthropic API key.

Lives under `services/` (not `applications/`) because it needs a
`ClusterRoleBinding`, which only the `services` AppProject allows.

## What agents can and cannot reach

| Can | Cannot |
|---|---|
| Public internet (Anthropic, GitHub, npm, PyPI) | Any in-cluster Service (pc-broker, Temporal, Langfuse, …) |
| kube-apiserver with ClusterRole `view` (get/list/watch, logs) | Secrets, `exec`, `port-forward`, `proxy`, any write |
| `/home/paseo` and `/workspace` on the PVC | The LAN (Postgres VM, the PC, AdGuard, gateway-internal) |

Enforced by `networkpolicy.yaml` (the cluster's first Cilium policy; it only
selects this pod) and `clusterrolebinding.yaml`. Keep both that way:
anything an agent can reach, a prompt-injected agent can reach.

## Secrets (Infisical)

Create these keys in the `k3s-homelab` project, `lab` environment, before first
sync.

| Infisical key | Ends up as | How to create |
|---|---|---|
| `paseo-password` | env `PASEO_PASSWORD` | `openssl rand -base64 32`. Guards the API/WebSocket; the static UI stays public. |
| `paseo-claude-code-oauth-token` | env `CLAUDE_CODE_OAUTH_TOKEN` | `claude setup-token` on a machine logged in to the Pro account. Acts as the whole Claude account: rotate if leaked. |
| `paseo-github-app-private-key` | Secret `paseo-github-app`, **not** in the pod | The GitHub App's `.pem`, pasted whole. Only the ESO generator reads it. |

Both env keys are readable by every agent. Env vars are read at pod start:
after changing one, wait for the ExternalSecret refresh (1h, or annotate it to
force) and restart the pod.

### GitHub: App `5707698`, installation `180765222`

Agents never hold a long-lived GitHub credential. `github-app.yaml` has ESO's
`GithubAccessToken` generator mint a one-hour installation token every 30
minutes into Secret `paseo-github-token`, mounted at `/var/run/github/token`.
`git` (credential helper in `GIT_CONFIG_*`) and `gh` (a wrapper around
`gh-bin`) read that file on every call, so refreshes need no restart and there
is nothing to rotate on a schedule.

- **Repos:** whatever the App installation is granted (GitHub → Settings →
  Applications → the App → Configure). Changing it needs no secret change.
  **Never grant `k3s-homelab` or `cloud-infrastructure`**: a push to their
  `main` deploys (Argo CD / HCP Terraform).
- **Permissions:** the App has Contents + Pull requests read/write and no
  Workflows, so agents cannot edit CI. The generator also caps each token at
  `contents`/`pull_requests: write`, so widening the App later does not widen
  agent tokens.
- **Rotate the private key only if it leaks:** generate a new key on the App
  page, replace `paseo-github-app-private-key` in Infisical, delete the old key
  on GitHub.
- **Check minting:** `kubectl -n paseo get externalsecret paseo-github-token`
  should be `SecretSynced`; if not, `kubectl -n paseo describe` it (wrong IDs
  or key format show up there).

## Versions

| Component | Pinned in | Notes |
|---|---|---|
| Paseo `0.15.4` (index digest) | `deployment.yaml`, both `paseo` images | Must stay `>= 0.5.0` (GHSA-2xhx-c69r-qj4j, relay E2EE bypass). |
| Claude Code `2.1.322` | `install-claude-code` env | `DISABLE_AUTOUPDATER=1` keeps it pinned. |
| kubectl `v1.35.10` + sha256 | `install-cli-tools` env | Stay within one minor of the k3s server. |
| gh `2.103.3` | `install-cli-tools` env | Verified against the release's `checksums.txt`; installed as `gh-bin` behind the token-reading `gh` wrapper. |

The init containers install the CLIs onto the PVC and skip work when the
recorded version matches, so a bump is an env change plus a pod restart.

## Connecting

- Phone/laptop: Twingate on, open `https://paseo.mattshan.dev`, enter the
  password. **Do not enable relay pairing**; the direct path is the only one
  this setup intends (the relay was the vector for GHSA-2xhx-c69r-qj4j).
- Start agents in the default mode (approvals), not full-access.

## First-deploy checklist

1. Infisical keys above created.
2. DNS: `paseo.mattshan.dev → 192.168.1.194` in AdGuard (see `docs/dns.md`).
3. After sync:
   - `kubectl -n paseo get externalsecret,pod` → `SecretSynced`, pod `Running`.
   - Read-only RBAC: each prints `no`:
     ```sh
     for a in "get secrets" "create pods/exec" "create pods/portforward" \
              "get services/proxy" "delete pods" "patch deployments"; do
       kubectl auth can-i $a -A --as=system:serviceaccount:paseo:paseo
     done
     ```
   - Network, from the pod (`kubectl -n paseo exec deploy/paseo -- sh`):
     `curl -m5 https://api.anthropic.com` succeeds; `kubectl get pods -A`
     works; `curl -m5 http://pc-broker-service.pc-broker.svc:8000` and
     `curl -m5 http://192.168.1.178:5432` time out.
   - `https://paseo.mattshan.dev` loads; API calls fail without the password;
     an agent session streams (WebSocket through the gateway).
   - `gh auth status` and a `git push` to a scratch repo work.
4. Run one agent end to end on a scratch repo before adding real ones.

## Troubleshooting

- **Pod stuck in `Init`**: `kubectl -n paseo logs deploy/paseo -c install-cli-tools`
  (or `-c install-claude-code`). A checksum mismatch means the pinned version
  and hash disagree; fix the pin, never drop the check.
- **Agents can't reach a host they need**: that host is either in-cluster or on
  the LAN and blocked on purpose. Add a narrow rule to `networkpolicy.yaml`
  (one endpoint, one port; for pc-broker an L7 rule for `POST /api/chat` only),
  not a broad allow.
- **No Hubble/flows for drops**: `kubectl -n kube-system exec ds/cilium -- cilium-dbg monitor --type drop`.
