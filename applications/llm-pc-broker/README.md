# llm-pc-broker

Proxies LLM requests to an Ollama instance running on a home PC, handling wake-on-LAN
and readiness polling automatically.

Source repo: <https://github.com/matthewshan/llm-pc-broker>  
Image: `ghcr.io/matthewshan/llm-pc-broker:latest`  
Hostname: `llm-broker.mattshan.dev`

## Secret

The deployment references `llm-pc-broker-secrets`. Create it out-of-band before ArgoCD
syncs the application:

```sh
kubectl create secret generic llm-pc-broker-secrets \
  --namespace llm-pc-broker \
  --from-literal=PC_MAC='aa:bb:cc:dd:ee:ff' \
  --from-literal=API_TOKEN='changeme' \
  --from-literal=SHUTDOWN_AGENT_TOKEN='' \
  --from-literal=SHUTDOWN_AGENT_URL=''
```

| Key                    | Description                                      |
|------------------------|--------------------------------------------------|
| `PC_MAC`               | MAC address of the target PC for Wake-on-LAN     |
| `API_TOKEN`            | Bearer token required by the broker API          |
| `SHUTDOWN_AGENT_TOKEN` | Token for the remote shutdown agent (optional)   |
| `SHUTDOWN_AGENT_URL`   | URL of the remote shutdown agent (optional)      |

## ConfigMap overrides

Non-sensitive config lives in `configmap.yaml`. Adjust `PC_HOST`, `PC_BROADCAST`, and
`OLLAMA_BASE_URL` to match your network layout before merging.
