## Plan: Migrate Repo Secrets to Infisical

Move the repo’s manually bootstrapped runtime secrets into Infisical and sync them into Kubernetes with External Secrets, while keeping only the External Secrets Universal Auth credential as a manual bootstrap secret and leaving Argo CD admin bootstrap out of scope. The External Secrets bootstrap is already healthy in-cluster, so the remaining work is workload cutover: add namespace-local ExternalSecret resources for the dependent components, verify they can take over the existing Kubernetes Secret contracts cleanly, and replace the manual secret bootstrap instructions in docs with an Infisical seeding workflow.

**Current cluster state already verified**
- `Application/external-secrets` in Argo CD is `Synced` and `Healthy`
- External Secrets controller pods in namespace `external-secrets` are running
- `ClusterSecretStore/infisical` exists and validates successfully against Infisical
- The bootstrap secret `external-secrets/infisical-universal-auth` already exists in-cluster

**Infisical source of truth already seeded**
- Project/environment: `k3s-homelab` / `lab`
- Flat Infisical keys currently present and treated as the canonical source of truth:
   - `cloudflare-api-token`
   - `cloudflare-emails`
   - `cloudflare-tunnel-credentials`
   - `grafana-cloud-logs-username`
   - `grafana-cloud-metrics-username`
   - `grafana-cloud-otlp-username`
   - `grafana-cloud-password`
   - `n8n-encryption-key`
   - `twingate-api-key`
   - `twingate-remote-network-id`

**Required ExternalSecret mappings from Infisical to Kubernetes**
- `cloudflare-api-token` Kubernetes Secret in namespace `cert-manager`
   - target key `api-token` <- Infisical `cloudflare-api-token`
   - target key `email` <- Infisical `cloudflare-emails`
- `tunnel-credentials` Kubernetes Secret in namespace `cloudflared`
   - target key `credentials.json` <- Infisical `cloudflare-tunnel-credentials`
- `twingate-operator-auth` Kubernetes Secret in namespace `twingate`
   - target key `TWINGATE_API_KEY` <- Infisical `twingate-api-key`
   - target key `TWINGATE_REMOTE_NETWORK_ID` <- Infisical `twingate-remote-network-id`
- `grafana-cloud-auth-grafana-k8s-monitoring` Kubernetes Secret in namespace `monitoring`
   - target key `metricsUsername` <- Infisical `grafana-cloud-metrics-username`
   - target key `logsUsername` <- Infisical `grafana-cloud-logs-username`
   - target key `otlpUsername` <- Infisical `grafana-cloud-otlp-username`
   - target key `password` <- Infisical `grafana-cloud-password`
- `n8n-secret` Kubernetes Secret in namespace `n8n`
   - target key `N8N_ENCRYPTION_KEY` <- Infisical `n8n-encryption-key`

**Not migrated to Infisical/External Secrets**
- `external-secrets/infisical-universal-auth` remains a manual bootstrap Kubernetes secret because External Secrets cannot fetch its own provider credentials
- `argocd/argocd-secret` stays bootstrap/manual and out of scope for this migration
- `cert-manager/cloudflare-key` remains cert-manager managed
- `headlamp` token stays on-demand/generated, not GitOps managed

**Steps**
1. Treat the existing flat Infisical keys as the source of truth and document the required mappings into namespace-qualified Kubernetes secrets. Preserve the current Kubernetes secret names and key names exactly so consuming manifests do not need to change their secret references.
2. Run a preflight ownership check before cutover: determine whether `cloudflare-api-token`, `tunnel-credentials`, `twingate-operator-auth`, `grafana-cloud-auth-grafana-k8s-monitoring`, and `n8n-secret` already exist in the cluster and verify that the new `ExternalSecret` resources can take over those existing Secret names cleanly.
3. Update the External Secrets bootstrap documentation to make `infisical-universal-auth` the only manual Kubernetes secret prerequisite and to document the required Infisical project/environment (`k3s-homelab` / `lab`) plus the exact flat Infisical keys listed above.
4. Add ExternalSecret manifests for the included workloads, keeping target secret names identical to the existing contracts and using `ClusterSecretStore` `infisical` with a conservative refresh interval. Each ExternalSecret should map from the flat Infisical key names above into the existing Kubernetes secret contract. This can be done in parallel after step 2 for:
   - cert-manager Cloudflare credentials
   - cloudflared tunnel credentials
   - Twingate operator credentials
   - Grafana Cloud credentials
   - n8n encryption key
5. Wire each new ExternalSecret into the owning kustomization and remove or replace any placeholder/manual-secret guidance in manifests. Reuse existing consumer references in Helm values and Deployments rather than changing workload configuration.
6. Handle cert-manager carefully: replace the current placeholder secret manifest with an ExternalSecret-backed secret and keep ordering explicit relative to `ClusterIssuer` so Argo applies the ExternalSecret before the issuer resource. Because the actual Secret is created asynchronously by the operator, plan verification around a two-sync or wait-for-ready flow rather than assuming a single sync is enough.
7. Update repo docs so setup and operations match the new secret flow. `docs/setup.md` should add an External Secrets bootstrap step immediately after the Cilium section (per user request), then replace later manual `kubectl create secret` steps with instructions to maintain the flat Infisical key set above and let External Secrets reconcile the namespace secrets. Update topic docs and component READMEs that currently instruct manual secret creation.
8. Validate the migration end-to-end in dependency order: confirm the External Secrets app and store remain healthy, then confirm ExternalSecrets are Healthy and target Secrets created, then confirm the dependent apps/controllers are `Healthy` and `Synced` in Argo CD.
9. After successful cutover, remove or sanitize any old operator-owned secret material that should no longer be the source of truth, especially `secrets.md` if it still contains live runtime credentials.

**Relevant files**
- `/home/matthew/Code/k3s-homelab/infrastructure/controllers/external-secrets/README.md` — rewrite bootstrap guidance around Infisical seeding plus the one remaining manual bootstrap secret
- `/home/matthew/Code/k3s-homelab/infrastructure/controllers/external-secrets/infisical-cluster-secret-store.yaml` — verify project/environment assumptions only; no secret material here
- `/home/matthew/Code/k3s-homelab/infrastructure/controllers/cert-manager/kustomization.yaml` — include the cert-manager ExternalSecret manifest
- `/home/matthew/Code/k3s-homelab/infrastructure/controllers/cert-manager/cloudflare-secret.yaml` — likely replace or rename this placeholder Secret manifest into the ExternalSecret resource for `cloudflare-api-token`
- `/home/matthew/Code/k3s-homelab/infrastructure/controllers/cert-manager/cluster-issuer.yaml` — preserve the existing `cloudflare-api-token` reference and confirm ordering expectations
- `/home/matthew/Code/k3s-homelab/infrastructure/networking/cloudflared/kustomization.yaml` — include the tunnel credentials ExternalSecret and remove the “manual secret” comment
- `/home/matthew/Code/k3s-homelab/infrastructure/networking/cloudflared/daemon-set.yaml` — keep the `tunnel-credentials` mount contract unchanged
- `/home/matthew/Code/k3s-homelab/infrastructure/networking/twingate/kustomization.yaml` — include the Twingate ExternalSecret manifest
- `/home/matthew/Code/k3s-homelab/infrastructure/networking/twingate/values.yaml` — keep existing secret references intact; no inline secrets
- `/home/matthew/Code/k3s-homelab/infrastructure/networking/twingate/README.md` — replace manual secret-creation steps with Infisical + External Secrets instructions
- `/home/matthew/Code/k3s-homelab/infrastructure/monitoring/grafana/kustomization.yaml` — include the Grafana credentials ExternalSecret manifest
- `/home/matthew/Code/k3s-homelab/infrastructure/monitoring/grafana/values.yaml` — preserve `existingSecretName` contract for the Grafana Cloud auth secret
- `/home/matthew/Code/k3s-homelab/infrastructure/monitoring/grafana/README.md` — replace manual secret bootstrap with Infisical seeding instructions
- `/home/matthew/Code/k3s-homelab/services/n8n/kustomization.yaml` — include the n8n ExternalSecret manifest
- `/home/matthew/Code/k3s-homelab/services/n8n/deployment.yaml` — preserve the current `n8n-secret` reference
- `/home/matthew/Code/k3s-homelab/services/n8n/README.md` — replace manual secret creation guidance
- `/home/matthew/Code/k3s-homelab/docs/setup.md` — update bootstrap order and replace manual secret creation commands with Infisical seeding workflow
- `/home/matthew/Code/k3s-homelab/docs/networking.md` — update Twingate and cloudflared operational notes to reference External Secrets instead of manual secrets
- `/home/matthew/Code/k3s-homelab/docs/monitoring.md` — add or adjust the Grafana secret-management note if the Grafana README alone is not enough for operators
- `/home/matthew/Code/k3s-homelab/infrastructure/infrastructure-components-appset.yaml` — review only if rollout needs a repo-level ordering change beyond a staged migration

**Verification**
1. Confirm the existing bootstrap remains healthy: `kubectl get clustersecretstore infisical -o yaml` should still show `Ready=True`, and the `external-secrets` Argo CD application should remain `Healthy` and `Synced`.
2. Before cutover, check whether the target Kubernetes Secrets already exist and record any ownership or adoption conflicts that the new `ExternalSecret` resources might hit.
3. For each migrated namespace, confirm `kubectl get externalsecret -A` shows Healthy/Ready and the target Kubernetes Secret exists with the expected key names.
4. Verify cert-manager can read `cloudflare-api-token` and that `kubectl describe clusterissuer cloudflare-cluster-issuer` reaches Ready without missing-secret errors.
5. Verify cloudflared pods mount `tunnel-credentials` successfully and do not crash on missing `/etc/cloudflared/credentials` content.
6. Verify Twingate operator and Grafana workloads come up without “secret not found” errors and that n8n starts with `N8N_ENCRYPTION_KEY` populated.
7. Review Argo CD application health after rollout: `cert-manager`, `cloudflared`, `twingate`, `grafana`, and `n8n` should all be `Healthy` and `Synced`.

**Decisions**
- Included scope: cert-manager, cloudflared, Twingate, Grafana, n8n
- Excluded scope: Argo CD admin secret, headlamp token, cert-manager generated ACME private key
- Required bootstrap exception: `infisical-universal-auth` stays manual in Kubernetes
- Source-of-truth format: flat Infisical keys are canonical; Kubernetes secret names and key names are derived through ExternalSecret mappings
- Current rollout state: External Secrets bootstrap is already complete in-cluster; remaining work is the workload cutover phase

**Further Considerations**
1. Prefer keeping the existing Kubernetes secret names and key names unchanged while treating the existing flat Infisical keys as canonical; this minimizes workload edits and avoids renaming secrets that already exist in Infisical.
2. Because the bootstrap is already complete in-cluster, the main rollout risk is no longer controller ordering; it is ownership conflict or adoption behavior when `ExternalSecret` resources target Secret names that may already exist from manual bootstrap.
3. For the Cloudflare tunnel credentials, document that the tunnel still has to be created manually with `cloudflared tunnel create`; only the resulting `credentials.json` storage location changes from a direct Kubernetes secret to Infisical-backed reconciliation.
4. After successful cutover, old secret material outside Infisical should be treated as stale and removed or sanitized so operators do not accidentally use the wrong source of truth.
