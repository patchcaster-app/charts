{{/* Common names, labels and derived values. */}}

{{- define "patchcaster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "patchcaster.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "patchcaster.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name (.Chart.Version | replace "+" "_") }}
app.kubernetes.io/name: {{ include "patchcaster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "patchcaster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "patchcaster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Image reference: a digest wins over any tag. Without an explicit tag the
chart pulls the application's release tag, v<appVersion>: the application
tags its images vX.Y.Z, while appVersion carries the bare X.Y.Z that
releases set from the tag. A leading v in appVersion is not doubled.
*/}}
{{- define "patchcaster.imageRef" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- $releaseTag := printf "v%s" (trimPrefix "v" .Chart.AppVersion) -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default $releaseTag) -}}
{{- end -}}
{{- end -}}

{{/*
Secret consumed by the Deployment: the chart-managed one unless existingSecret
points at externally managed material (keys: database-url, mattermost-token,
signing-secrets).
*/}}
{{- define "patchcaster.secretName" -}}
{{- if .Values.existingSecret -}}
{{- .Values.existingSecret -}}
{{- else -}}
{{- printf "%s-secrets" (include "patchcaster.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
terminationGracePeriodSeconds, derived strictly greater than drainTimeout
(SYSREQ-023 owner condition). Only whole s/m/h durations are accepted so the
derivation stays exact; anything else fails the render with an actionable
message rather than guessing.
*/}}
{{- define "patchcaster.graceSeconds" -}}
{{- $t := .Values.drainTimeout | toString -}}
{{- $secs := -1 -}}
{{- if regexMatch "^[0-9]+$" $t -}}
{{- $secs = $t | int -}}
{{- else if regexMatch "^[0-9]+s$" $t -}}
{{- $secs = trimSuffix "s" $t | int -}}
{{- else if regexMatch "^[0-9]+m$" $t -}}
{{- $secs = mul (trimSuffix "m" $t | int) 60 -}}
{{- else if regexMatch "^[0-9]+h$" $t -}}
{{- $secs = mul (trimSuffix "h" $t | int) 3600 -}}
{{- end -}}
{{- if lt $secs 0 -}}
{{- fail (printf "drainTimeout %q must be a whole number of s, m or h (e.g. 30s): terminationGracePeriodSeconds is derived from it and must stay exact" $t) -}}
{{- end -}}
{{- add $secs 3 -}}
{{- end -}}
