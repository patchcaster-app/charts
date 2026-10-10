# PatchCaster Helm charts

The [PatchCaster](https://github.com/patchcaster-app/patchcaster) Helm chart,
published as an OCI artifact. Specification: `SYSREQ-033`; decision: `ADR-017`
(both in the application repository's `docs/specs/`).

## Install

```sh
helm install patchcaster oci://ghcr.io/patchcaster-app/charts/patchcaster \
  --version <X.Y.Z> \
  --namespace patchcaster --create-namespace \
  --set mattermostUrl=https://mm.example.com \
  --set secrets.databaseUrl='postgres://…?sslmode=require' \
  --set secrets.mattermostToken=… \
  --set secrets.signingSecrets[0]=… \
  --set-file routing.file=./routing.yaml
```

Or use a values file. `helm show values` of the artifact lists every knob with
its comment; `values.schema.json` rejects misspelled keys at install time.

Required material: a PostgreSQL 18 the pod can reach (migrations run at
startup; the chart provisions nothing), a Mattermost bot token whose account
is in every routed channel, and the routing table (one `channel` per
`project`; see `contrib/routing.example.yaml` in the application repo).

The chart renders: Deployment (probes on the internal listener, hardened
securityContext, grace period derived strictly larger than `drainTimeout`),
Service (webhook + internal/metrics), Secret (or bring your own via
`existingSecret`), routing ConfigMap (rollout on change), optional
ServiceAccount and optional Gateway API HTTPRoute. Deliberately absent:
Ingress, HPA, bundled PostgreSQL.

## Exposing the webhook

GitLab has to reach `POST /webhook` on the service's webhook port. With
[Gateway API](https://gateway-api.sigs.k8s.io/) in the cluster, the chart
attaches an HTTPRoute to a Gateway your platform already runs, and TLS
terminates at that Gateway's listener:

```yaml
httpRoute:
  enabled: true
  parentRefs:
    - name: public              # your Gateway
      namespace: gateway-system
      sectionName: https        # optional: attach to one listener only
  hostnames:
    - patchcaster.example.com
```

The Gateway's `allowedRoutes` must admit the release's namespace. Only the
`/webhook` path is routed, so the internal port (probes, metrics) stays
in-cluster. Without Gateway API, expose the `webhook` service port with
whatever your platform uses instead.

## Verify provenance

Charts are signed keyless with cosign v3 at publish time (Actions OIDC), so
verify them with cosign v3 or later. The identity is **this repository's**
release workflow:

```sh
cosign verify \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp 'https://github\.com/patchcaster-app/charts/\.github/workflows/release\.yml@refs/tags/v.+' \
  ghcr.io/patchcaster-app/charts/patchcaster:<X.Y.Z>
```

The image the chart pins (`appVersion`) carries its own signature under the
*application* repository's identity — see its
[install guide](https://github.com/patchcaster-app/patchcaster/blob/main/docs/install.md#verify-what-you-deploy).

While the repository is private, the ghcr packages are private too:
authenticate (`helm registry login ghcr.io …` / `imagePullSecrets`) or flip
package visibility.

## Development

Requirements: `helm` 4.x and `kind` on PATH; `just` for the task aliases.

```sh
just chart-check    # helm lint --strict + full render of ci/test-values.yaml
just chart-render   # the same render, printed
just chart-package 0.0.1   # package into dist/ with an explicit version
```

CI additionally validates every manifest against a live API server
(`kind` + `helm install --dry-run=server`).

Releasing: push a `v*` tag **in this repository**. The workflow packages
(`version` = `appVersion` = tag), pushes
`oci://ghcr.io/patchcaster-app/charts/patchcaster:<tag>`, and signs the pushed
digest. Tag the application and the chart the same version together; parity
is checked at release acceptance (`helm show chart`), not enforced by
automation — see ADR-017 for why.
