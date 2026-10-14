# Chart repository tasks.
# helm is ambient (developed against helm 4.3, API v2 throughout; also
# bundled on GitHub runners). cosign for release signing comes from the
# cosign-installer action in the release workflow, as in the application
# repository (ADR-016/017). It is not invoked from here.

default: chart-check

# The CI gate: strict lint plus a full render of the CI values.
chart-check:
	helm lint --strict charts/patchcaster
	helm template patchcaster charts/patchcaster --values charts/patchcaster/ci/test-values.yaml >/dev/null

# Render the CI values to stdout for eyeballing.
chart-render:
	helm template patchcaster charts/patchcaster --values charts/patchcaster/ci/test-values.yaml

# Needs kind and a container engine. With podman, export
# KIND_EXPERIMENTAL_PROVIDER=podman first.
# Install the chart for real as an application release (e.g. 0.1.0) in a throwaway kind cluster.
chart-smoke app_version:
	smoke/install.sh {{app_version}}

# Package with an explicit version; the release workflow does exactly this,
# setting version and appVersion both to the tag (SYSREQ-033).
chart-package version:
	helm package charts/patchcaster --version {{version}} --app-version {{version}} --destination dist/
