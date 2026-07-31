# AdGuard Home DNS

Cluster CoreDNS forwards `mattshan.dev` to the AdGuard Home server at `192.168.1.107` so in-cluster workloads such as the Twingate connector resolve the same private answers as LAN clients.

argocd.mattshan.dev 192.168.1.194
it-tools.mattshan.dev 192.168.1.194
headlamp.mattshan.dev 192.168.1.194
n8n.mattshan.dev 192.168.1.194
longhorn.mattshan.dev 192.168.1.194
pc.mattshan.dev 192.168.1.194
temporal.mattshan.dev 192.168.1.194
langfuse.mattshan.dev 192.168.1.194

## Adding a new service hostname

These rewrites are configured by hand in AdGuard Home (**Filters → DNS rewrites**); they
are not GitOps-managed, so adding an `HTTPRoute` alone is not enough to make a service
reachable. Add the record here **and** in AdGuard whenever a new hostname is exposed.

Symptom when the record is missing: the browser reports `PR_END_OF_FILE_ERROR` (or a
generic TLS/connection failure). The Twingate `*.mattshan.dev` resource still matches, so
the client gets a Twingate address and the connection is attempted — but the connector
cannot resolve the hostname to a backend, so it closes the connection before the TLS
handshake finishes. The gateway and certificate are fine; only DNS is missing. Confirm with:

```sh
# from inside the cluster — should return 192.168.1.194
kubectl run dns --rm -i --restart=Never --image=curlimages/curl:8.11.1 \
  --command -- nslookup <host>.mattshan.dev
```

A single wildcard rewrite (`*.mattshan.dev` → `192.168.1.194`) would cover every current
and future service, since the gateway already terminates a wildcard certificate and
Twingate already exposes a wildcard resource. Worth considering instead of maintaining
this list — the trade-off is that typos then resolve to the gateway and return a 404 from
Cilium rather than failing fast in DNS.