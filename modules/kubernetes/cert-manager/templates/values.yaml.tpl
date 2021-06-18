installCRDs: true

global:
  priorityClassName: "platform-low"

%{ if provider == "azure" }
podLabels:
  aadpodidbinding: cert-manager
%{ endif }
%{ if provider == "aws" }
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "${aws_config.role_arn}"
securityContext:
  fsGroup: 1001
%{ endif }

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limit:
    memory: 512Mi

webhook:
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
    limit:
      memory: 64Mi

cainjector:
  resources:
    requests:
      cpu: 100m
      memory: 300Mi
    limit:
      memory: 512Mi
