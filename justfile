# Chart repository tasks.
# helm is ambient (developed against helm 4.3, API v2 throughout; also
# bundled on GitHub runners). cosign for release signing is the pinned
# tools/cosign module, mirroring the application repository (ADR-016/017) —
# it is invoked by the release workflow, not from here.

default: chart-check

# The CI gate: strict lint plus a full render of the CI values.
chart-check:
	helm lint --strict charts/patchcaster
	helm template patchcaster charts/patchcaster --values charts/patchcaster/ci/test-values.yaml >/dev/null

# Render the CI values to stdout for eyeballing.
chart-render:
	helm template patchcaster charts/patchcaster --values charts/patchcaster/ci/test-values.yaml

# Package with an explicit version; the release workflow does exactly this,
# setting version and appVersion both to the tag (SYSREQ-033).
chart-package version:
	helm package charts/patchcaster --version {{version}} --app-version {{version}} --destination dist/
