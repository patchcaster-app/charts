#!/usr/bin/env bash
# Installs the chart for real, as the given application release, into a
# throwaway kind cluster with a disposable PostgreSQL, and waits until the
# pod is ready. Usage: smoke/install.sh <app-version>, for example 0.1.0.
#
# The chart is packaged the way a release packages it, so a passing run
# proves that the chart pulls an image that exists and that the application
# starts with what the chart renders. The cluster gets its own kubeconfig
# file, so the caller's kubectl configuration stays untouched. Export
# KIND_EXPERIMENTAL_PROVIDER=podman to run it with podman.
set -euo pipefail

version="${1:?usage: smoke/install.sh <app-version>, for example 0.1.0}"
version="${version#v}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chart="${here}/../charts/patchcaster"
cluster="patchcaster-smoke"
namespace="patchcaster"
work="$(mktemp -d)"
export KUBECONFIG="${work}/kubeconfig"

# report shows why an install failed, so a CI failure needs no rerun to tell.
report() {
	kubectl -n "${namespace}" get pods -o wide || true
	kubectl -n "${namespace}" describe pods || true
	kubectl -n "${namespace}" logs --all-containers --prefix \
		--selector app.kubernetes.io/name=patchcaster || true
}

trap 'rm -rf "${work}"' EXIT
kind create cluster --name "${cluster}" --kubeconfig "${KUBECONFIG}" --wait 120s
# Only a cluster this run created is deleted again.
trap 'kind delete cluster --name "${cluster}" --kubeconfig "${KUBECONFIG}"; rm -rf "${work}"' EXIT
trap report ERR

kubectl create namespace "${namespace}"
kubectl -n "${namespace}" apply -f "${here}/postgres.yaml"
kubectl -n "${namespace}" rollout status deployment/postgres --timeout=180s

helm package "${chart}" --version "${version}" --app-version "${version}" --destination "${work}"
helm install patchcaster "${work}/patchcaster-${version}.tgz" \
	--namespace "${namespace}" --values "${here}/values.yaml" \
	--wait --timeout 180s
echo "PatchCaster ${version} installed and ready"
