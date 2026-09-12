{{/*
Helper templates for the nextcloud chart.
Resource names, labels and selectors are fixed (not derived from the release
name): the original Kustomize manifests used these exact names.
*/}}

{{- define "nextcloud.ns" -}}
{{ .Values.namespace.name }}
{{- end -}}

{{/* `annotations:` block with the keep policy, or nothing. */}}
{{- define "nextcloud.keepAnnotations" -}}
{{- if .Values.keepOnUninstall -}}
annotations:
  helm.sh/resource-policy: keep
{{- end -}}
{{- end -}}
