## Plan: Migrate Repo Secrets to Infisical

Move the repo’s manually bootstrapped runtime secrets into Infisical and sync them into Kubernetes with External Secrets, while keeping only the External Secrets Universal Auth credential as a manual bootstrap secret and leaving Argo CD admin bootstrap out of scope. Implement this as a staged rollout: first make External Secrets itself healthy, then add namespace-local ExternalSecret resources for the dependent components, and finally replace the manual secret bootstrap instructions in docs with an Infisical seeding workflow.

**Secrets to seed into Infisical**
- `cert-manager/cloudflare-api-token`: keys `api-token`, `email`
- `cloudflared/tunnel-credentials`: key `credentials.json`
- `twingate/twingate-operator-auth`: keys `TWINGATE_API_KEY`, `TWINGATE_REMOTE_NETWORK_ID`
- `monitoring/grafana-cloud-auth-grafana-k8s-monitoring`: keys `metricsUsername`, `logsUsername`, `otlpUsername`, `password`
- `n8n/n8n-secret`: key `N8N_ENCRYPTION_KEY`

**Not migrated to Infisical/External Secrets**
- `external-secrets/infisical-universal-auth` remains a manual bootstrap Kubernetes secret because External Secrets cannot fetch its own provider credentials
- `argocd/argocd-secret` stays bootstrap/manual and out of scope for this migration
- `cert-manager/cloudflare-key` remains cert-manager managed
- `headlamp` token stays on-demand/generated, not GitOps managed

**Steps**
1. Confirm and document the target secret contract in Infisical: one namespace-qualified Kubernetes secret per workload, preserving the current Kubernetes secret names and key names exactly so consuming manifests do not need to change their secret references.
2. Stage the rollout so External Secrets is available before any `ExternalSecret` objects are introduced. This blocks all later steps because the repo’s ApplicationSets do not currently enforce per-component ordering among infrastructure apps beyond the group-level appsets.
3. Update the External Secrets bootstrap documentation to make `infisical-universal-auth` the only manual Kubernetes secret prerequisite and to document the required Infisical project/environment (`k3s-homelab` / `lab`) plus the list of runtime secrets that must be entered into Infisical.
4. Add ExternalSecret manifests for the included workloads, keeping target secret names identical to the existing contracts and using `ClusterSecretStore` `infisical` with a conservative refresh interval. This can be done in parallel after step 2 for:
   - cert-manager Cloudflare credentials
   - cloudflared tunnel credentials
   - Twingate operator credentials
   - Grafana Cloud credentials
   - n8n encryption key
5. Wire each new ExternalSecret into the owning kustomization and remove or replace any placeholder/manual-secret guidance in manifests. Reuse existing consumer references in Helm values and Deployments rather than changing workload configuration.
6. Handle cert-manager carefully: replace the current placeholder secret manifest with an ExternalSecret-backed secret and keep ordering explicit relative to `ClusterIssuer` so Argo applies the ExternalSecret before the issuer resource. Because the actual Secret is created asynchronously by the operator, plan verification around a two-sync or wait-for-ready flow rather than assuming a single sync is enough.
7. Update repo docs so setup and operations match the new secret flow. `docs/setup.md` should add an External Secrets bootstrap step immediately after the Cilium section (per user request), then replace later manual `kubectl create secret` steps with instructions to seed Infisical and let External Secrets reconcile the namespace secrets. Update topic docs and component READMEs that currently instruct manual secret creation.
8. Check in this finalized migration plan as a new Markdown file under `docs/plans/` in the repository, following the style of the existing checked-in plan docs, so the repo keeps an operator-facing record alongside the implementation instead of leaving the plan only in session memory.
9. Validate the migration end-to-end in dependency order: External Secrets app healthy and store Ready first, then ExternalSecrets Healthy and target Secrets created, then dependent apps/controllers healthy.

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
1. Confirm `kubectl get clustersecretstore infisical -o yaml` shows `Ready=True` after creating `infisical-universal-auth` and syncing the External Secrets component.
2. For each migrated namespace, confirm `kubectl get externalsecret -A` shows Healthy/Ready and the target Kubernetes Secret exists with the expected key names.
3. Verify cert-manager can read `cloudflare-api-token` and that `kubectl describe clusterissuer cloudflare-cluster-issuer` reaches Ready without missing-secret errors.
4. Verify cloudflared pods mount `tunnel-credentials` successfully and do not crash on missing `/etc/cloudflared/credentials` content.
5. Verify Twingate operator and Grafana workloads come up without “secret not found” errors and that n8n starts with `N8N_ENCRYPTION_KEY` populated.
6. Review Argo CD application health after rollout to catch any CRD-timing or sync-order regressions; if necessary, execute as two commits/two sync waves rather than a single all-at-once sync.

**Decisions**
- Included scope: cert-manager, cloudflared, Twingate, Grafana, n8n
- Excluded scope: Argo CD admin secret, headlamp token, cert-manager generated ACME private key
- Required bootstrap exception: `infisical-universal-auth` stays manual in Kubernetes
- Recommended rollout shape: two stages/commits so External Secrets CRDs and controller are already running before other apps introduce `ExternalSecret` resources

**Further Considerations**
1. Prefer keeping the existing Kubernetes secret names and key names unchanged; this minimizes workload edits and reduces rollback risk.
2. If a single-step Git change is required instead of a staged rollout, investigate Application/ApplicationSet ordering for infra components before implementation; the current repo shape does not obviously guarantee External Secrets comes up before cert-manager/cloudflared/twingate/grafana apps apply their `ExternalSecret` objects.
3. For the Cloudflare tunnel credentials, document that the tunnel still has to be created manually with `cloudflared tunnel create`; only the resulting `credentials.json` storage location changes from a direct Kubernetes secret to Infisical-backed reconciliation.
