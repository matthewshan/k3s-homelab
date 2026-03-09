# Cluster Triage Commands

Use these commands as a starting point. Narrow to a namespace or label selector as soon as the failing domain becomes clearer.

## Global Health

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
```

If a metrics API is available in the cluster, these can help:

```bash
kubectl top nodes
kubectl top pods -A
```

## Focused Pod Triage

```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace> --previous
kubectl logs <pod> -n <namespace> -c <container> --previous
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

## Controllers

```bash
kubectl get deploy,statefulset,daemonset -n <namespace>
kubectl describe deployment <name> -n <namespace>
kubectl rollout status deployment/<name> -n <namespace>
```

## Services and Endpoints

```bash
kubectl get svc,endpoints,endpointslices -n <namespace>
kubectl describe svc <service> -n <namespace>
```

## Gateway API

```bash
kubectl get gateways,gatewayclasses,httproutes -A
kubectl describe gateway <gateway> -n <namespace>
kubectl describe httproute <route> -n <namespace>
kubectl get httproute <route> -n <namespace> -o yaml
```

## Argo CD

```bash
kubectl get applications,applicationsets -n argocd
kubectl describe application <app> -n argocd
kubectl get events -n argocd --sort-by=.lastTimestamp
kubectl get pods -n argocd -o wide
```

## cert-manager

```bash
kubectl get pods -n cert-manager
kubectl get certificates,certificaterequests,orders,challenges -A
kubectl describe certificate <name> -n <namespace>
kubectl describe clusterissuer <name>
```

## Cilium

```bash
kubectl get pods -n kube-system -l k8s-app=cilium -o wide
kubectl get ciliuml2announcementpolicies,ciliumbgpclusterconfigs,ciliumloadbalancerippools -A
kubectl describe ciliumloadbalancerippool <name>
kubectl get svc -A | findstr LoadBalancer
```

If `cilium` is available on a node after SSH access, deeper checks may include:

```bash
cilium status
cilium service list
```

## Longhorn

```bash
kubectl get pods -n longhorn-system
kubectl get pvc,pv -A
kubectl describe pvc <name> -n <namespace>
kubectl get volumes.longhorn.io -n longhorn-system
```

## Node and k3s Signals

```bash
kubectl describe node <node>
kubectl get events -A --field-selector involvedObject.kind=Node --sort-by=.lastTimestamp
kubectl get pods -n kube-system -o wide
```
