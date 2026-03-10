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
