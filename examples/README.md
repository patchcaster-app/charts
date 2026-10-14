# Deployment examples

Two declarative ways to run the chart. Both read their credentials from an
existing Secret, so none end up in Git:

```sh
kubectl create namespace patchcaster
kubectl -n patchcaster create secret generic patchcaster \
  --from-literal=database-url='postgres://…?sslmode=require' \
  --from-literal=mattermost-token='…' \
  --from-literal=signing-secrets='…'   # comma-separated while a secret rotates
```

In a GitOps repository, produce the same Secret with SOPS or External Secrets
instead.

* [`flux/`](flux/): an `OCIRepository` that only accepts charts signed by this
  repository's release workflow, and a `HelmRelease` built from it. Needs
  Flux 2.8 or later, which verifies cosign v3 signatures.
* [`helmfile/`](helmfile/): a helmfile that pins the chart and verifies its
  signature in a `prepare` hook. Needs helmfile 1.x and cosign v3.

Both pin chart `0.1.0`; change it to the release you deploy. The chart and the image are public, so neither needs registry credentials.
