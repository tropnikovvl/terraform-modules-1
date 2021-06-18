forceNameSpaced: true

mic:
  prometheusPort: 8888
  priorityClassName: "platform-medium"
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 200m
      memory: 1024Mi

nmi:
  allowNetworkPluginKubenet: true
  prometheusPort: 9090
  priorityClassName: "platform-high"
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 200m
      memory: 512Mi

azureIdentities:
%{ for namespace in namespaces ~}
  "${namespace.name}":
    namespace: "${namespace.name}"
    type: "0"
    resourceID: "${aad_pod_identity[namespace.name].id}"
    clientID: "${aad_pod_identity[namespace.name].client_id}"
    binding:
      name: "${namespace.name}"
      selector: "${namespace.name}"
%{ endfor }
