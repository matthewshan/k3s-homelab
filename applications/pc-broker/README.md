# pc-broker

[pc-broker](https://github.com/matthewshan/pc-broker) — wake and shut down the
gaming PC from a phone over Twingate, at `https://pc.mattshan.dev` (internal via
`gateway-internal`). Image published to ghcr.io by that repo's CI.

## How it works

- **Wake** is a Wake-on-LAN magic packet. A pod on the Cilium overlay can't
  broadcast onto the LAN, so the Deployment runs with `hostNetwork: true` +
  `dnsPolicy: ClusterFirstWithHostNet` and broadcasts from the node's LAN
  interface. The k3s node (`192.168.1.163`) and the PC (`192.168.1.77`) are on
  the same `192.168.1.0/24` segment.
- **Shutdown** is delegated to a small agent running on the PC (the `agent/`
  dir in the app repo), reached at `SHUTDOWN_AGENT_URL`.

## Sync order

Wave-gated: namespace (−2) → `ExternalSecret` (−1) → app
Deployment/Service/HTTPRoute (default 0).

## Secrets (Infisical)

Create these keys in the `k3s-homelab` project, `lab` environment, before first
sync:

| Infisical key | Becomes env | Notes |
|---|---|---|
| `pc-broker-mac` | `PC_MAC` | NIC MAC for the WoL packet (`04:7c:16:15:cc:33`) |
| `pc-broker-shutdown-agent-token` | `SHUTDOWN_AGENT_TOKEN` | Shared bearer token; must match `agent/install.ps1 -Token` |

`API_TOKEN` is optional and intentionally omitted (defaults to empty → no
app-level auth; access is gated by Twingate). Add it as another key if you want
to require a token on `/api/power/off`.

Non-secret config (`PC_HOST`, `PC_BROADCAST`, `SHUTDOWN_AGENT_URL`,
`HOST_REACHABILITY_TIMEOUT`, `POLL_INTERVAL`) lives in `configmap.yaml`.

## First-deploy checklist

1. ghcr package `pc-broker` must be **public** (or add an `imagePullSecret`) —
   created on the first CI publish (tag `v0.1.0` in the app repo).
2. Infisical keys above created.
3. PC has a static DHCP reservation for `192.168.1.77`, WoL enabled, and Fast
   Startup disabled (see the app repo's `agent/README.md`).
4. DNS: `pc.mattshan.dev → 192.168.1.194` in AdGuard.
5. Shutdown agent installed on the PC (`agent/install.ps1`).
