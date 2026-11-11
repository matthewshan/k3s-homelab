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
| `paseo-linear-api-key` | env `LINEAR_API_KEY` (Secret `paseo-linear`) | Linear → Settings → Security & access → Personal API keys. Use a dedicated key just for Paseo so it can be revoked on its own. Optional: without it agents simply have no Linear tools. |
| `paseo-github-app-private-key` | Secret `paseo-github-app`, **not** in the pod | The GitHub App's `.pem`, pasted whole. Only the ESO generator reads it. |

All env keys are readable by every agent. The Linear key is the same accepted
risk as the Claude token: it acts as you in Linear, so revoke it there if an
agent may have leaked it. Env vars are read at pod start: after changing or
rotating one, wait for the ExternalSecret refresh (1h, or annotate it to force)
and restart the pod.

### Linear MCP

At start, the container merges a `linear` entry (`https://mcp.linear.app/mcp`,
`Authorization: Bearer $LINEAR_API_KEY`) into the user-scope Claude config,
`$CLAUDE_CONFIG_DIR/.claude.json` (`/home/paseo/.claude/.claude.json` on the
PVC, mode 0600), keeping every other key; with no key it removes the entry. So
every agent session gets Linear tools with no `claude mcp add`, and the key is
also at rest in that file. A failure only logs `Linear MCP: …` and the daemon
starts anyway (`kubectl -n paseo logs deploy/paseo | grep 'Linear MCP'`).

`paseo-linear-api-key` has its own ExternalSecret, `paseo-linear`, consumed
with `optional: true`: if the Infisical key is missing, only that
ExternalSecret fails, and the password and Claude token keep refreshing.
`/etc/claude-code/managed-mcp.json` is deliberately not used: a managed MCP
file can take exclusive control of MCP servers and could block the `paseo` server
the daemon injects.

### GitHub: App `5707698`, installation `180765222`

Agents never hold a long-lived GitHub credential. `github-app.yaml` has ESO's
`GithubAccessToken` generator mint a one-hour installation token every 30
minutes into Secret `paseo-github-token`, mounted at `/var/run/github/token`.
`git` (credential helper in `GIT_CONFIG_*`) and `gh` (a wrapper around
the real binary) read that file on every call, so refreshes need no restart and there
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
| Paseo `0.15.4` (index digest) | `deployment.yaml` | Must stay `>= 0.5.0` (GHSA-2xhx-c69r-qj4j, relay E2EE bypass). |
| alpine `3.22` (index digest) | `install-tools` image | Only downloads and verifies; supported until 2027-05. |
| Claude Code `2.1.322` + sha256 | `install-tools` env | Native `claude-code-linux-x64` tarball straight from the npm registry; no npm, no install scripts. |
| kubectl `v1.35.10` + sha256 | `install-tools` env | Stay within one minor of the k3s server. |
| gh `2.103.3` + sha256 | `install-tools` env | Behind a `gh` wrapper that reads the current App token. |

`install-tools` downloads all three on every pod start (~7s, ~400MB), checks
each against its pinned sha256 and fails closed on any mismatch or missing
hash, then puts them in an `emptyDir` that the daemon mounts **read-only** at
`/opt/paseo-tools`. They deliberately never touch the PVC: agents can write
there, and a swapped binary would run in every later session. To bump one,
change its version and hash together; get the hash from the upstream release
(`kubectl`: `<url>.sha256`; gh: `gh_<v>_checksums.txt`; Claude Code:
`sha256sum` of the registry tarball after checking its `dist.integrity`).

## Hardening beyond RBAC and the network policy

- **Password required:** the upstream entrypoint only *warns* and then serves an
  unauthenticated control API when `PASEO_PASSWORD` is empty; the container
  command refuses to start unless it is at least 24 characters.
- **Claude Code managed policy** (`claude-managed-settings.yaml`, read-only at
  `/etc/claude-code`): no bypass-permissions ("full-access") sessions, and only
  managed hooks run, so an agent cannot plant a hook in `~/.claude` or a repo
  that fires in later sessions.
- **Residual:** agents run as the same user as the daemon, so they can read the
  daemon's env (password, Claude token), `~/.paseo` (including
  `daemon-keypair.json`) and edit dotfiles on the PVC, and they have open
  internet egress. Approvals are the control for that; if you suspect an agent
  was prompt-injected, rotate `paseo-password` and the Claude token and wipe
  the PVC (re-pair afterwards).

## Connecting

- Phone/laptop: Twingate on, open `https://paseo.mattshan.dev`, enter the
  password. **Do not enable relay pairing**; the direct path is the only one
  this setup intends (the relay was the vector for GHSA-2xhx-c69r-qj4j).
- Start agents in the default mode (approvals), not full-access.

## First-deploy checklist

1. Infisical keys above created (`paseo-linear-api-key` is optional).
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
   - Linear: `kubectl -n paseo get externalsecret paseo-linear` is
     `SecretSynced`, and `claude mcp list` in the pod shows `linear` connected.
   - Tools are read-only: `touch /opt/paseo-tools/bin/claude` fails; and a
     session in full-access mode is refused or downgraded (managed policy).
4. Run one agent end to end on a scratch repo before adding real ones.

## Troubleshooting

- **No Linear tools in a session**: `kubectl -n paseo logs deploy/paseo | grep 'Linear MCP'`.
  "not set" means Secret `paseo-linear` was missing at pod start (check
  `kubectl -n paseo describe externalsecret paseo-linear`, then restart the
  pod); a 401 in `claude mcp list` means the key is wrong or revoked.

- **Pod stuck in `Init`**: `kubectl -n paseo logs deploy/paseo -c install-tools`.
  A sha256 mismatch means the pinned version and hash disagree (or the download
  was tampered with); fix the pin from upstream, never drop the check.
- **Container exits at start with "refusing to start"**: `paseo-password` is
  missing or too short in Infisical.
- **Agents can't reach a host they need**: that host is either in-cluster or on
  the LAN and blocked on purpose. Add a narrow rule to `networkpolicy.yaml`
  (one endpoint, one port; for pc-broker an L7 rule for `POST /api/chat` only),
  not a broad allow.
- **No Hubble/flows for drops**: `kubectl -n kube-system exec ds/cilium -- cilium-dbg monitor --type drop`.
