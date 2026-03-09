# Networking

## Cilium Logging

This repo keeps Cilium debug logging disabled in [infrastructure/networking/cilium/values.yaml](c:/Users/Matthew%20Shan/Code/k3s-homelab/infrastructure/networking/cilium/values.yaml) so routine agent debug messages do not flood Grafana Loki.

Normal Cilium warnings and errors still ship through the Grafana monitoring stack.

If deeper Cilium troubleshooting is needed, temporarily set `debug.enabled: true`, sync the Cilium component, capture the needed logs, and then turn it back off.
