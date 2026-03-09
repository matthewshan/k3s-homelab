---
name: kubernetes-troubleshooting
description: 'Troubleshoot Kubernetes and k3s cluster issues with kubectl-first diagnosis. Use for broken pods, failed deployments, Argo CD sync problems, Cilium networking issues, Gateway API routing failures, cert-manager problems, Longhorn/storage faults, node health issues, and optional SSH-based node investigation when kubectl is insufficient.'
argument-hint: 'What is broken, where is it failing, and what signals have you already seen?'
user-invocable: true
---

# Kubernetes Troubleshooting

Use this skill when diagnosing cluster or workload failures in this homelab repository. The workflow is kubectl-first, evidence-driven, and escalates to a generic `ssh <node>` fallback only if the Kubernetes API does not expose enough information.

This repo is GitOps-managed through Argo CD ApplicationSets. Infrastructure components are generated from `infrastructure/networking/*`, `infrastructure/storage/*`, `infrastructure/controllers/*`, and `infrastructure/monitoring/*`. Services are generated from `services/*`. Prefer checking both live cluster state and the corresponding manifests in this workspace.

## When to Use

- Pods are crash looping, pending, or not becoming ready.
- A service is unreachable through Gateway API or HTTPRoute.
- Argo CD shows degraded, out-of-sync, or missing applications.
- DNS, TLS, cert-manager, or cloudflared behavior is broken.
- Cilium networking, load balancer IPs, or service connectivity are failing.
- Longhorn volumes, PVCs, or mounts are stuck.
- A node looks unhealthy or the k3s control plane appears degraded.

## Troubleshooting Rules

- Start broad, then narrow the scope.
- Gather evidence before proposing changes.
- Prefer read-only inspection first.
- Compare live objects with the GitOps source in this repo before changing manifests.
- If a fault can be explained at the Kubernetes object level, do not jump to SSH.
- Use SSH only as a fallback for node-level issues such as disk pressure, kubelet/container runtime problems, CNI state, kernel modules, host networking, or k3s service failures.
- Stay diagnostic-first. Do not jump to recovery commands unless the diagnosis is already supported by evidence and the next step is explicitly requested.

## Procedure

1. Define the failure clearly.

Capture:
- What is broken.
- The namespace, app, node, URL, or IP involved.
- Whether the failure is new, intermittent, or after a recent change.
- Whether the symptom is control plane, workload, networking, storage, or routing related.

2. Check cluster-wide health first.

Use commands from [triage-commands.md](./references/triage-commands.md) to inspect:
- node readiness
- kube-system pods
- warning events
- recently restarting or non-ready pods

If cluster-wide signals already show the failure domain, continue there.

3. Identify the failing object and reason.

Inspect the specific workload or resource:
- `kubectl get` for summary state
- `kubectl describe` for conditions, scheduling failures, probe failures, image pull errors, mount errors, or controller messages
- `kubectl logs` for container-level failures
- `kubectl get events` in namespace order by time

4. Branch by failure domain.

### Workload failures

Use when pods are pending, crash looping, or never become ready.

Check:
- deployment, statefulset, daemonset, job, or pod conditions
- image pull failures
- readiness and liveness probes
- secret and configmap references
- PVC mounts and storage class bindings
- resource pressure and scheduling constraints

### GitOps and Argo CD failures

Use when expected resources are missing, drifted, or degraded.

Check:
- Argo CD applications and ApplicationSets in `argocd`
- sync status, health status, and controller events
- whether the path exists in this repo and matches the intended namespace
- whether the appset generator path should include the component

Relevant repo anchors:
- `infrastructure/infrastructure-components-appset.yaml`
- `services/services-appset.yaml`
- `applications/applications-appset.yaml`

### Networking and routing failures

Use when services are unreachable, external IPs are missing, or Gateway API traffic is not flowing.

Check:
- service endpoints and port mappings
- HTTPRoute status and parent refs
- Gateway status, listeners, and attached routes
- DNS resolution and TLS secret references
- Cilium pods, Cilium status, load balancer IP allocation, and L2 announcement configuration
- cloudflared pods and tunnel configuration if external ingress depends on Cloudflare Tunnel

### TLS and certificate failures

Use when certificates are missing, invalid, or not renewing.

Check:
- cert-manager pods and events
- Certificate, CertificateRequest, Order, and Challenge resources
- ClusterIssuer readiness and referenced secrets
- target secret existence in the destination namespace

### Storage failures

Use when PVCs are pending, pods cannot mount volumes, or data paths are unhealthy.

Check:
- PVC and PV status
- StorageClass bindings
- Longhorn system health
- attach, mount, and filesystem errors from pod events and node messages

### Node or k3s failures

Use when the API is unstable, nodes flap, workloads disappear unexpectedly, or daemon-level services break.

Check:
- node conditions and pressure states
- kube-system and CNI health
- k3s-related events or control plane pod failures

If Kubernetes-level signals are insufficient, continue to the SSH fallback below.

5. Compare live state with Git state.

Before recommending a manifest change:
- inspect the relevant YAML in this repo
- confirm the namespace, labels, selectors, ports, hostnames, secrets, and references align with live state
- prefer fixing the declared source of truth instead of issuing imperative changes, unless the issue is operational and time-sensitive

6. Escalate to SSH only when needed.

SSH is appropriate when:
- nodes are NotReady without a clear Kubernetes reason
- disk, memory, filesystem, or network interface issues are suspected
- k3s service logs are required
- container runtime, Cilium host networking, or kernel module issues need host inspection

Suggested SSH investigations:
- `ssh <node>`
- `sudo systemctl status k3s`
- `sudo journalctl -u k3s -n 200 --no-pager`
- `sudo journalctl -u k3s --since "30 min ago" --no-pager`
- `sudo crictl ps -a`
- `sudo crictl logs <container-id>`
- `df -h`
- `free -m`
- `ip a`
- `sudo lsmod | grep -E "xt_socket|iptable_raw"`

Only recommend SSH commands that directly test the active hypothesis.

Assume local access provides `kubectl`. Do not assume local `argocd` or `cilium` CLIs. If already connected to a node over SSH and `cilium` is present there, it can be used for deeper node-level network inspection.

7. Conclude with a diagnosis and next action.

The response should end with:
- the most likely root cause
- the evidence supporting it
- the smallest safe next step
- whether the fix belongs in GitOps manifests, operational recovery steps, or node remediation

## Completion Checks

The troubleshooting pass is complete when:
- the failure domain is identified
- the concrete failing resource is named
- the likely root cause is supported by logs, conditions, events, or status fields
- the next step is specific and minimal
- any recommendation that changes desired state points back to the repo manifests

## Repo-Specific Hotspots

- Argo CD control plane: `infrastructure/controllers/argocd`
- Cilium networking: `infrastructure/networking/cilium`
- Gateway API resources: `infrastructure/networking/gateway`
- cert-manager: `infrastructure/controllers/cert-manager`
- cloudflared: `infrastructure/networking/cloudflared`
- Longhorn: `infrastructure/storage/longhorn`
- Grafana monitoring: `infrastructure/monitoring/grafana`

## Reference

- [Cluster triage commands](./references/triage-commands.md)