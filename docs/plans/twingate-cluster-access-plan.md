## Plan: Twingate Cluster Access

Use the existing Twingate operator install to provide private access from Twingate-enrolled devices to the cluster’s internal Gateway API endpoints and to the Kubernetes API for `kubectl` and Freelens. The repo already routes browser apps through the internal gateway at `192.168.1.194`, so the plan should extend that model instead of creating a second internal exposure path.

**Goals**

1. Allow a device signed in to Twingate to open internal app URLs such as `argocd.mattshan.dev`, `headlamp.mattshan.dev`, `n8n.mattshan.dev`, `it-tools.mattshan.dev`, and `longhorn.mattshan.dev`.
2. Allow the same device to run `kubectl` against the cluster API.
3. Allow Freelens to connect using the same reachable Kubernetes API endpoint.
4. Keep credentials out of Git and follow the repo’s existing operator-managed secret pattern.

**Current State**

- The Twingate operator is already installed from the upstream Helm chart in `infrastructure/networking/twingate/kustomization.yaml`.
- Operator credentials are expected from the pre-created `twingate-operator-auth` secret referenced by `infrastructure/networking/twingate/values.yaml`.
- Internal browser traffic already lands on `gateway-internal` in `infrastructure/networking/gateway/gw-internal.yaml`, which owns `192.168.1.194` and serves `*.mattshan.dev` on ports `80` and `443`.
- Local DNS in `docs/dns.md` points internal app hostnames at `192.168.1.194`, which means that IP is the internal gateway address, not an individual app Service IP.
- Representative app routes such as `services/headlamp/httproute.yaml`, `services/n8n/httproute.yaml`, and `applications/it-tools/httproute.yaml` already bind those hostnames to `gateway-internal`.
- The cluster bootstrap notes in `docs/setup.md` currently expect Kubernetes clients to talk directly to the node IP `192.168.1.163:6443`.

**DNS Strategy**

- Twingate can resolve private hostnames for connected clients even when those clients cannot reach the home LAN DNS server directly, but only if the requested hostname exists as a Twingate resource.
- DNS resolution moves from the client side to the Connector side: the Twingate client intercepts the query, forwards it through Twingate, and the Connector resolves the hostname from inside the private network.
- For this repo, the important private answer is still the internal gateway IP `192.168.1.194` defined in `infrastructure/networking/gateway/gw-internal.yaml`.
- If a Connector resolves `argocd.mattshan.dev` or `headlamp.mattshan.dev` via public DNS instead of private split DNS, the client may reach the wrong destination or bypass the intended internal-gateway path.
- The practical requirement is not "client must reach a home DNS server"; it is "Connector must have a DNS path that returns the internal answers for `*.mattshan.dev`."

**Recommended DNS Options**

1. Preferred: make Twingate the primary resolution path for enrolled devices by defining explicit host resources for the internal names you care about.
2. Ensure the Twingate Connector runs on a host whose DNS path resolves those names to `192.168.1.194`, or otherwise has a private resolution path for those hostnames.
3. Use Twingate aliases where helpful for operator convenience, but keep the real `*.mattshan.dev` hostnames as the primary access targets.
4. Avoid relying on public DNS for these internal names if the public answer points to Cloudflare Tunnel or another external path, because that defeats the goal of predictable private access.

**Recommended Approach**

1. Use Twingate for two distinct access categories:
   - browser access to internal app hostnames through the existing internal gateway
   - direct network access to the Kubernetes API endpoint for `kubectl` and Freelens
2. Keep the current internal hostnames and gateway flow for web apps rather than exposing per-app Service IPs.
3. Start with explicit per-service Twingate resources for the existing internal DNS names instead of a wildcard resource. This keeps access clearer and easier to audit.
4. Add a separate Twingate resource for the Kubernetes API at `192.168.1.163:6443` so CLI and desktop clients can connect without changing cluster ingress.
5. Revisit wildcard domain access only after the explicit resources are working and the operator CRDs are confirmed to support the desired policy shape.

**Implementation Steps**

1. Confirm the exact Twingate CRDs installed by chart version `0.29.0` and identify the resource types needed for:
   - at least one `TwingateConnector`
   - per-destination access resources for internal apps
   - a TCP or network-level access resource for the Kubernetes API
2. Add operator-managed manifests under `infrastructure/networking/twingate` for one or more Twingate connectors so the cluster can advertise reachable internal destinations to Twingate.
3. Create Twingate access resources for the internal app hostnames already used by the repo:
   - `argocd.mattshan.dev`
   - `headlamp.mattshan.dev`
   - `n8n.mattshan.dev`
   - `it-tools.mattshan.dev`
   - `longhorn.mattshan.dev`
   Add more hostnames later by following the same pattern as new `HTTPRoute` resources are introduced.
4. Create a separate Twingate access resource for the Kubernetes API endpoint at `192.168.1.163:6443`.
5. Validate client behavior from a Twingate-connected device:
   - web apps resolve and load over the internal gateway
   - `kubectl get nodes` works using a kubeconfig that points at `https://192.168.1.163:6443`
   - Freelens can import the same kubeconfig and connect successfully
6. Update operational docs after implementation so another operator can recreate the Twingate secret contract, connector expectations, and client-side usage.

**Resource Model Options**

- **Preferred first pass: explicit host resources**
  - One Twingate resource per internal app hostname on `443`
  - One separate Kubernetes API resource on `192.168.1.163:6443`
  - Best fit for least privilege and current repo layout
- **Broader option: wildcard domain access**
  - Expose `*.mattshan.dev` through a single Twingate resource if the operator CRDs support it cleanly
  - Lower manifest count, but broader than necessary and less explicit for access review
- **Broadest option: gateway IP access**
  - Grant access to `192.168.1.194:443`
  - Simplest network-wise, but loses hostname-level intent and is weaker for policy boundaries

**Kubernetes Client Access Notes**

- `kubectl` and Freelens do not need the HTTP gateway. They need direct network access to the Kubernetes API server.
- The repo currently documents the API endpoint as the node IP `192.168.1.163:6443`, so that is the safest first target for Twingate access.
- If a future change introduces a DNS name for the Kubernetes API, verify the k3s server certificate includes that hostname as a SAN before switching kubeconfigs.
- Headlamp remains useful as a browser-based fallback, but it does not replace direct API connectivity for `kubectl` or Freelens.

**Secrets and Operational Constraints**

- Keep using the pre-created `twingate-operator-auth` secret for the operator install contract.
- Do not commit live Twingate API keys, remote network IDs, access tokens, or refresh tokens.
- If the operator creates connector credentials automatically, prefer that workflow over any manually managed connector token secrets.
- If manual connector secrets are required for a fallback path, document their creation in repo docs without storing live values.

**Relevant Files**

- `infrastructure/networking/twingate/kustomization.yaml`: installs the upstream Twingate operator chart.
- `infrastructure/networking/twingate/values.yaml`: operator network slug and existing secret references.
- `infrastructure/networking/twingate/README.md`: current secret bootstrap guidance for the operator.
- `infrastructure/networking/gateway/gw-internal.yaml`: internal gateway IP and wildcard hostname listeners.
- `docs/dns.md`: current internal DNS names pointing to `192.168.1.194`.
- `services/headlamp/httproute.yaml`: existing internal route for Headlamp.
- `services/n8n/httproute.yaml`: existing internal route for n8n.
- `applications/it-tools/httproute.yaml`: existing internal route for IT-Tools.
- `docs/networking.md`: best place to document the Twingate access model after implementation.

**Verification**

1. Confirm Argo CD can reconcile the new Twingate manifests without CRD diff noise beyond the existing known normalization for `apiVersion`.
2. Confirm at least one connector becomes healthy in Twingate after sync.
3. From a Twingate-connected device, verify DNS resolution and HTTPS access for each internal hostname.
4. From the same device, verify `kubectl get nodes` and `kubectl get ns` against `https://192.168.1.163:6443`.
5. Import the same kubeconfig into Freelens and verify cluster connection succeeds.

**Decisions**

- Use the existing internal gateway and DNS pattern; do not create a parallel internal ingress stack.
- Treat browser access and Kubernetes API access as separate problems with separate Twingate resources.
- Prefer explicit resources first, then consider wildcard access only if the operator CRDs and your access policy needs make it worthwhile.
- Twingate should become the preferred resolution path for enrolled devices, while local split DNS can remain a LAN-side fallback for devices that are not using Twingate.
- Keep documentation in `docs/` and avoid adding to `docs/setup.md` unless explicitly requested.

**Further Considerations**

1. Connector placement: one connector may be enough for a single-node lab, but two replicas or two connectors may be worth planning if you want access to survive a pod restart.
2. DNS behavior on Twingate clients: make Twingate the preferred resolution path for `*.mattshan.dev` on enrolled devices, and keep local DNS available only as a fallback for on-LAN devices that are not using Twingate.
3. API endpoint stability: if the node IP could change later, plan a stable DNS name or virtual IP for the Kubernetes API before distributing long-lived kubeconfigs.
4. Access groups: once the base path works, map app access and Kubernetes API access to separate Twingate groups so cluster administration stays narrower than general internal app access.
