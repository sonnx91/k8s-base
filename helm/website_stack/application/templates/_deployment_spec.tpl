{{- define "application.deploymentSpec" -}}

{{/* Go Templates do not support variable updating, so we simulate it using dictionaries */}}
{{- $hasInjectionTypes := dict "hasVolume" false "hasEnvVars" false "hasIRSA" false "exposePorts" false -}}
{{- if .Values.envVars -}}
  {{- $_ := set $hasInjectionTypes "hasEnvVars" true -}}
{{- end -}}
{{- if .Values.additionalContainerEnv -}}
  {{- $_ := set $hasInjectionTypes "hasEnvVars" true -}}
{{- end -}}
{{- $allContainerPorts := values .Values.containerPorts -}}
{{- range $allContainerPorts -}}
  {{/* We are exposing ports if there is at least one key in containerPorts that is not disabled (disabled = false or omitted)*/}}
  {{- if or (not (hasKey . "disabled")) (not .disabled) -}}
    {{- $_ := set $hasInjectionTypes "exposePorts" true -}}
  {{- end -}}
{{- end -}}
{{- $allSecrets := values .Values.secrets -}}
{{- range $allSecrets -}}
  {{- if eq (index . "as") "volume" -}}
    {{- $_ := set $hasInjectionTypes "hasVolume" true -}}
  {{- else if eq (index . "as") "environment" -}}
    {{- $_ := set $hasInjectionTypes "hasEnvVars" true -}}
  {{- else if eq (index . "as") "none" -}}
    {{- /* noop */ -}}
  {{- else -}}
    {{- fail printf "secrets config has unknown type: %s" (index . "as") -}}
  {{- end -}}
{{- end -}}
{{- $allConfigMaps := values .Values.configMaps -}}
{{- range $allConfigMaps -}}
  {{- if eq (index . "as") "volume" -}}
    {{- $_ := set $hasInjectionTypes "hasVolume" true -}}
  {{- else if eq (index . "as") "environment" -}}
    {{- $_ := set $hasInjectionTypes "hasEnvVars" true -}}
  {{- else if eq (index . "as") "none" -}}
    {{- /* noop */ -}}
  {{- else -}}
    {{- fail printf "configMaps config has unknown type: %s" (index . "as") -}}
  {{- end -}}
{{- end -}}
{{- if gt (len .Values.persistentVolumes) 0 -}}
  {{- $_ := set $hasInjectionTypes "hasVolume" true -}}
{{- end -}}
{{- if gt (len .Values.scratchPaths) 0 -}}
  {{- $_ := set $hasInjectionTypes "hasVolume" true -}}
{{- end -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "application.fullname" . }}
  labels:
    # https://docs.helm.sh/chart_best_practices/#standard-labels
    helm.sh/chart: {{ include "application.chart" . }}
    app.kubernetes.io/name: {{ include "application.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    {{- range $key, $value := .Values.additionalDeploymentLabels }}
    {{ $key }}: {{ $value }}
    {{- end}}
{{- with .Values.deploymentAnnotations }}
  annotations:
{{ toYaml . | indent 4 }}
{{- end }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "application.name" . }}
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ include "application.name" . }}
        app.kubernetes.io/instance: {{ .Release.Name }}
        {{- range $key, $value := .Values.additionalPodLabels }}
        {{ $key }}: {{ $value }}
        {{- end }}

      {{- with .Values.podAnnotations }}
      annotations:
{{ toYaml . | indent 8 }}
      {{- end }}
    spec:
      {{- if gt (len .Values.serviceAccount.name) 0 }}
      serviceAccountName: "{{ .Values.serviceAccount.name }}"
      {{- end }}
      {{- if hasKey .Values.serviceAccount "automountServiceAccountToken" }}
      automountServiceAccountToken : {{ .Values.serviceAccount.automountServiceAccountToken }}
      {{- end }}
      {{- if .Values.podSecurityContext }}
      securityContext:
{{ toYaml .Values.podSecurityContext | indent 8 }}
      {{- end}}

      containers:
        - name: {{ .Values.applicationName }}
          {{- $repo := required ".Values.containerImage.repository is required" .Values.containerImage.repository }}
          {{- $tag := required ".Values.containerImage.tag is required" .Values.containerImage.tag }}
          image: "{{ $repo }}:{{ $tag }}"
          imagePullPolicy: {{ .Values.containerImage.pullPolicy | default "IfNotPresent" }}
          {{- if .Values.containerCommand }}
          command:
{{ toYaml .Values.containerCommand | indent 12 }}
          {{- end }}

          {{- if index $hasInjectionTypes "exposePorts" }}
          ports:
            {{- /*
              NOTE: we check for a disabled flag here so that users of the helm
              chart can override the default containerPorts. Specifically, defining a new
              containerPorts in values.yaml will be merged with the default provided by the
              chart. For example, if the user provides:

                    containerPorts:
                      app:
                        port: 8080
                        protocol: TCP

              Then this is merged with the default and becomes:

                    containerPorts:
                      app:
                        port: 8080
                        protocol: TCP
                      http:
                        port: 80
                        protocol: TCP
                      https:
                        port: 443
                        protocol: TCP

              and so it becomes append as opposed to replace. To handle this,
              we allow users to explicitly disable predefined ports. So if the user wants to
              replace the ports with their own, they would provide the following values file:

                    containerPorts:
                      app:
                        port: 8080
                        protocol: TCP
                      http:
                        disabled: true
                      https:
                        disabled: true
            */ -}}
            {{- range $key, $portSpec := .Values.containerPorts }}
            {{- if not $portSpec.disabled }}
            - name: {{ $key }}
              containerPort: {{ int $portSpec.port }}
              protocol: {{ $portSpec.protocol }}
            {{- end }}
            {{- end }}
          {{- end }}

          {{- if .Values.startupProbe }}
          startupProbe:
{{ toYaml .Values.startupProbe | indent 12 }}
          {{- end }}

          {{- if .Values.livenessProbe }}
          livenessProbe:
{{ toYaml .Values.livenessProbe | indent 12 }}
          {{- end }}

          {{- if .Values.readinessProbe }}
          readinessProbe:
{{ toYaml .Values.readinessProbe | indent 12 }}
          {{- end }}
          {{- if .Values.securityContext }}
          securityContext:
{{ toYaml .Values.securityContext | indent 12 }}
          {{- end}}
          resources:
{{ toYaml .Values.containerResources | indent 12 }}

          {{- if gt (int .Values.shutdownDelay) 0 }}
          # Include a preStop hook with a shutdown delay for eventual consistency reasons.
          # See https://blog.gruntwork.io/delaying-shutdown-to-wait-for-pod-deletion-propagation-445f779a8304
          lifecycle:
            preStop:
              exec:
                command:
                  - sleep
                  - "{{ int .Values.shutdownDelay }}"
          {{- end }}

          {{- /* START ENV VAR LOGIC */ -}}
          {{- if index $hasInjectionTypes "hasEnvVars" }}
          env:
          {{- end }}
          {{- range $key, $value := .Values.envVars }}
            - name: {{ $key }}
              value: {{ quote $value }}
          {{- end }}
          {{- if .Values.additionalContainerEnv }}
{{ toYaml .Values.additionalContainerEnv | indent 12 }}
          {{- end }}
          {{- range $name, $value := .Values.configMaps }}
            {{- if eq $value.as "environment" }}
            {{- range $configKey, $keyEnvVarConfig := $value.items }}
            - name: {{ required "envVarName is required on configMaps items when using environment" $keyEnvVarConfig.envVarName | quote }}
              valueFrom:
                configMapKeyRef:
                  name: {{ $name }}
                  key: {{ $configKey }}
            {{- end }}
            {{- end }}
          {{- end }}
          {{- range $name, $value := .Values.secrets }}
            {{- if eq $value.as "environment" }}
            {{- range $secretKey, $keyEnvVarConfig := $value.items }}
            - name: {{ required "envVarName is required on secrets items when using environment" $keyEnvVarConfig.envVarName | quote }}
              valueFrom:
                secretKeyRef:
                  name: {{ $name }}
                  key: {{ $secretKey }}
            {{- end }}
            {{- end }}
          {{- end }}
          {{- if .Values.envFroms.enabled }}
          envFrom:
            - secretRef:
                name: {{ include "application.fullname" . }} 
          {{- end }}
          {{- /* END ENV VAR LOGIC */ -}}

          {{- /* START VOLUME MOUNT LOGIC */ -}}
          {{- if index $hasInjectionTypes "hasVolume" }}
          volumeMounts:
          {{- end }}
          {{- range $name, $value := .Values.configMaps }}
            {{- if eq $value.as "volume" }}
            - name: {{ $name }}-volume
              mountPath: {{ quote $value.mountPath }}
              {{- if $value.subPath }}
              subPath: {{ quote $value.subPath }}
              {{- end }}
            {{- end }}
          {{- end }}
          {{- range $name, $value := .Values.secrets }}
            {{- if eq $value.as "volume" }}
            - name: {{ $name }}-volume
              mountPath: {{ quote $value.mountPath }}
            {{- end }}
          {{- end }}
          {{- range $name, $value := .Values.persistentVolumes }}
            - name: {{ $name }}
              mountPath: {{ quote $value.mountPath }}
          {{- end }}
          {{- range $name, $value := .Values.scratchPaths }}
            - name: {{ $name }}
              mountPath: {{ quote $value }}
          {{- end }}
          {{- /* END VOLUME MOUNT LOGIC */ -}}

    {{- /* START IMAGE PULL SECRETS LOGIC */ -}}
    {{- if gt (len .Values.imagePullSecrets) 0 }}
      imagePullSecrets:
        {{- range $secretName := .Values.imagePullSecrets }}
        - name: {{ $secretName }}
        {{- end }}
    {{- end }}
    {{- /* END IMAGE PULL SECRETS LOGIC */ -}}

    {{- /* START VOLUME LOGIC */ -}}
    {{- if index $hasInjectionTypes "hasVolume" }}
      volumes:
    {{- end }}
    {{- range $name, $value := .Values.configMaps }}
      {{- if eq $value.as "volume" }}
        - name: {{ $name }}-volume
          configMap:
            name: {{ $name }}
            {{- if $value.items }}
            items:
              {{- range $configKey, $keyMountConfig := $value.items }}
              - key: {{ $configKey }}
                path: {{ required "filePath is required for configMap items" $keyMountConfig.filePath | quote }}
                {{- if $keyMountConfig.fileMode }}
                mode: {{ include "application.fileModeOctalToDecimal" $keyMountConfig.fileMode }}
                {{- end }}
              {{- end }}
            {{- end }}
      {{- end }}
    {{- end }}
    {{- range $name, $value := .Values.secrets }}
      {{- if eq $value.as "volume" }}
        - name: {{ $name }}-volume
          secret:
            secretName: {{ $name }}
            {{- if $value.items }}
            items:
              {{- range $secretKey, $keyMountConfig := $value.items }}
              - key: {{ $secretKey }}
                path: {{ required "filePath is required for secrets items" $keyMountConfig.filePath | quote }}
                {{- if $keyMountConfig.fileMode }}
                mode: {{ include "application.fileModeOctalToDecimal" $keyMountConfig.fileMode }}
                {{- end }}
              {{- end }}
            {{- end }}
      {{- end }}
    {{- end }}
    {{- range $name, $value := .Values.persistentVolumes }}
        - name: {{ $name }}
          persistentVolumeClaim:
            claimName: {{ $value.claimName }}
    {{- end }}
    {{- range $name, $value := .Values.scratchPaths }}
        - name: {{ $name }}
          emptyDir:
            medium: "Memory"
    {{- end }}
    {{- /* END VOLUME LOGIC */ -}}

    {{- with .Values.nodeSelector }}
      nodeSelector:
{{ toYaml . | indent 8 }}
    {{- end }}

    {{- with .Values.affinity }}
      affinity:
{{ toYaml . | indent 8 }}
    {{- end }}

    {{- with .Values.tolerations }}
      tolerations:
{{ toYaml . | indent 8 }}
    {{- end }}
{{- end -}}
