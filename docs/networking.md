# Networking

## Cilium Logging

This repo keeps Cilium debug logging disabled in [infrastructure/networking/cilium/values.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/networking/cilium/values.yaml) so routine agent debug messages do not flood Grafana Loki.

Normal Cilium warnings and errors still ship through the Grafana monitoring stack.

If deeper Cilium troubleshooting is needed, temporarily set `debug.enabled: true`, sync the Cilium component, capture the needed logs, and then turn it back off.

## Hubble UI

The Cilium component now includes a Gateway API `HTTPRoute` in `infrastructure/networking/cilium/httproute.yaml` that exposes the in-cluster `hubble-ui` service from `kube-system` at `hubble.mattshan.dev` through `gateway-internal`.

This repo only defines the route. DNS and any external/private access path still need to resolve `hubble.mattshan.dev` to the internal gateway IP `192.168.1.194` before the UI is reachable.

## Twingate Operator

The Twingate operator lives in `infrastructure/networking/twingate` and is installed from the upstream OCI Helm chart through Kustomize.

The `twingate-operator-auth` secret is managed by an `ExternalSecret`. Before syncing, seed the following keys into the Infisical project **`k3s-homelab`**, environment **`lab`**:

- `TWINGATE_API_KEY`
- `TWINGATE_REMOTE_NETWORK_ID`

The operator does not require `TWINGATE_ACCESS_TOKEN` or `TWINGATE_REFRESH_TOKEN` at install time. Those are connector credentials and are only needed for manual connector workflows outside the operator-managed path.

See `infrastructure/networking/twingate/README.md` for key descriptions and upgrade notes.

## Twingate cluster access

The repo now uses operator-managed Twingate objects in `infrastructure/networking/twingate` for two access paths:

- browser access to internal apps through the existing internal Gateway at `192.168.1.194`
- direct TCP access to the Kubernetes API at `192.168.1.163:6443`

It starts with a single connector and can grow to multiple connectors later if availability or placement needs change.

The managed app resource is a wildcard instead of per-app host entries:

- `*.mattshan.dev`

The repo creates one Twingate group:

- `Homelab Users` for browser access and Kubernetes API access

User membership stays out of Git. After sync, add users to that group in the Twingate Admin Console or manage membership through a separate non-public workflow.

The Twingate resources intentionally preserve the existing internal routing model:

- app hostnames stay pointed at `192.168.1.194`
- HTTP and HTTPS still terminate on `gateway-internal`
- `kubectl` and Freelens bypass the gateway and connect directly to `https://192.168.1.163:6443`

If a Twingate-connected device cannot open an internal app hostname, first verify that the connectors resolve `*.mattshan.dev` to the internal gateway IP rather than a public Cloudflare path.

## CoreDNS forward for mattshan.dev

The cluster adds a CoreDNS custom server block in `kube-system` so `mattshan.dev` queries forward to the AdGuard Home DNS server at `192.168.1.107`.

This keeps in-cluster resolution aligned with LAN clients and is especially important for the Twingate connector, which needs `argocd.mattshan.dev`, `headlamp.mattshan.dev`, `hubble.mattshan.dev`, `n8n.mattshan.dev`, `it-tools.mattshan.dev`, and `longhorn.mattshan.dev` to resolve to the internal gateway IP `192.168.1.194`.

The manifest lives under `infrastructure/networking/coredns` and relies on the default k3s CoreDNS `import /etc/coredns/custom/*.server` hook.

k3s also ships a default `import /etc/coredns/custom/*.override` line. This repo intentionally keeps an empty `00-empty.override` entry in the same ConfigMap so CoreDNS does not emit repeated `No files matching import glob pattern` warnings when no override snippets are needed.
