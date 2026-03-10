# Networking

## Cilium Logging

This repo keeps Cilium debug logging disabled in [infrastructure/networking/cilium/values.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/networking/cilium/values.yaml) so routine agent debug messages do not flood Grafana Loki.

Normal Cilium warnings and errors still ship through the Grafana monitoring stack.

If deeper Cilium troubleshooting is needed, temporarily set `debug.enabled: true`, sync the Cilium component, capture the needed logs, and then turn it back off.

## Twingate Operator

The Twingate operator lives in `infrastructure/networking/twingate` and is installed from the upstream OCI Helm chart through Kustomize.

Before syncing it, create the `twingate-operator-auth` secret in the `twingate` namespace with:

- `TWINGATE_API_KEY`
- `TWINGATE_REMOTE_NETWORK_ID`

The operator does not require `TWINGATE_ACCESS_TOKEN` or `TWINGATE_REFRESH_TOKEN` at install time. Those are connector credentials and are only needed for manual connector workflows outside the operator-managed path.

See `infrastructure/networking/twingate/README.md` for the secret creation command and upgrade notes.

## Twingate cluster access

The repo now uses operator-managed Twingate objects in `infrastructure/networking/twingate` for two access paths:

- browser access to internal apps through the existing internal Gateway at `192.168.1.194`
- direct TCP access to the Kubernetes API at `192.168.1.163:6443`

It starts with a single connector and can grow to multiple connectors later if availability or placement needs change.

The managed app resources are explicit hostnames instead of a wildcard:

- `argocd.mattshan.dev`
- `headlamp.mattshan.dev`
- `n8n.mattshan.dev`
- `it-tools.mattshan.dev`
- `longhorn.mattshan.dev`

The repo also creates two Twingate groups:

- `Homelab Users` for browser access
- `Homelab Cluster Admins` for Kubernetes API access

User membership stays out of Git. After sync, add users to those groups in the Twingate Admin Console or manage membership through a separate non-public workflow.

The Twingate resources intentionally preserve the existing internal routing model:

- app hostnames stay pointed at `192.168.1.194`
- HTTP and HTTPS still terminate on `gateway-internal`
- `kubectl` and Freelens bypass the gateway and connect directly to `https://192.168.1.163:6443`

If a Twingate-connected device cannot open an internal app hostname, first verify that the connectors resolve `*.mattshan.dev` to the internal gateway IP rather than a public Cloudflare path.
