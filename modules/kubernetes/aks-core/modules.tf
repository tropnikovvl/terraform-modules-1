locals {
  excluded_namespaces = [
    "kube-system",
    "aad-pod-identity",
    "azdo-proxy",
    "calico-system",
    "cert-manager",
    "csi-secrets-store-provider-azure",
    "datadog",
    "external-dns",
    "falco",
    "flux-system",
    "gatekeeper-system",
    "ingress-nginx",
    "linkerd",
    "linkerd-cni",
    "reloader",
    "starboard-operator",
    "tigera-operator",
    "velero",
    "grafana-agent",
    "promtail",
    "prometheus",
  ]
}

# OPA Gatekeeper
module "opa_gatekeeper_crd" {
  source = "../../kubernetes/helm-crd"

  chart_repository = "https://open-policy-agent.github.io/gatekeeper/charts"
  chart_name       = "gatekeeper"
  chart_version    = "3.7.1"
}

module "opa_gatekeeper" {
  depends_on = [module.opa_gatekeeper_crd]

  for_each = {
    for s in ["opa-gatekeeper"] :
    s => s
    if var.opa_gatekeeper_enabled
  }

  source = "../../kubernetes/opa-gatekeeper"

  enable_default_constraints = var.opa_gatekeeper_config.enable_default_constraints
  additional_constraints = concat(
    var.opa_gatekeeper_config.additional_constraints,
    [
      {
        kind               = "AzureIdentityFormat"
        name               = "azure-identity-format"
        enforcement_action = ""
        match = {
          kinds      = []
          namespaces = []
        }
        parameters = {}
      },
      {
        kind               = "K8sPodPriorityClass"
        name               = "pod-priority-class"
        enforcement_action = ""
        match = {
          kinds      = []
          namespaces = []
        }
        parameters = {
          permittedClassNames = ["platform-high", "platform-medium", "platform-low", "tenant-high", "tenant-medium", "tenant-low"]
        }
      },
    ]
  )
  enable_default_assigns = var.opa_gatekeeper_config.enable_default_assigns
  excluded_namespaces    = concat(var.opa_gatekeeper_config.additional_excluded_namespaces, local.excluded_namespaces)
  cloud_provider         = "azure"
}

# FluxCD v2
module "fluxcd_v2_azure_devops" {
  for_each = {
    for s in ["fluxcd-v2"] :
    s => s
    if var.fluxcd_v2_enabled && var.fluxcd_v2_config.type == "azure-devops"
  }

  source = "../../kubernetes/fluxcd-v2-azdo"

  environment       = var.environment
  cluster_id        = "${var.location_short}-${var.environment}-${var.name}${local.aks_name_suffix}"
  azure_devops_pat  = var.fluxcd_v2_config.azure_devops.pat
  azure_devops_org  = var.fluxcd_v2_config.azure_devops.org
  azure_devops_proj = var.fluxcd_v2_config.azure_devops.proj
  namespaces = [for ns in var.namespaces : {
    name = ns.name
    flux = {
      enabled     = ns.flux.enabled
      create_crds = ns.flux.create_crds
      org         = ns.flux.azure_devops.org
      proj        = ns.flux.azure_devops.proj
      repo        = ns.flux.azure_devops.repo
    }
  }]
}

module "fluxcd_v2_github" {
  for_each = {
    for s in ["fluxcd-v2"] :
    s => s
    if var.fluxcd_v2_enabled && var.fluxcd_v2_config.type == "github"
  }

  source = "../../kubernetes/fluxcd-v2-github"

  environment            = var.environment
  cluster_id             = "${var.location_short}-${var.environment}-${var.name}${local.aks_name_suffix}"
  github_org             = var.fluxcd_v2_config.github.org
  github_app_id          = var.fluxcd_v2_config.github.app_id
  github_installation_id = var.fluxcd_v2_config.github.installation_id
  github_private_key     = var.fluxcd_v2_config.github.private_key
  namespaces = [for ns in var.namespaces : {
    name = ns.name
    flux = {
      enabled = ns.flux.enabled
      repo    = ns.flux.github.repo
    }
  }]
}

# AAD-Pod-Identity
module "aad_pod_identity_crd" {
  source = "../../kubernetes/helm-crd"

  chart_repository = "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts"
  chart_name       = "aad-pod-identity"
  chart_version    = "4.1.10"
}

module "aad_pod_identity" {
  depends_on = [module.opa_gatekeeper, module.aad_pod_identity_crd]

  for_each = {
    for s in ["aad-pod-identity"] :
    s => s
    if var.aad_pod_identity_enabled
  }

  source = "../../kubernetes/aad-pod-identity"

  aad_pod_identity = var.aad_pod_identity_config
  namespaces = [for ns in var.namespaces : {
    name = ns.name
  }]
}

# AZ Metrics
module "azure_metrics" {
  depends_on = [module.opa_gatekeeper, module.aad_pod_identity_crd]

  for_each = {
    for s in ["azure-metrics"] :
    s => s
    if var.azure_metrics_enabled
  }

  source = "../../kubernetes/azure-metrics"

  client_id       = var.azure_metrics_config.client_id
  resource_id     = var.azure_metrics_config.resource_id
  subscription_id = data.azurerm_client_config.current.subscription_id
}

# linkerd
module "linkerd_crd" {
  source = "../../kubernetes/helm-crd-oci"

  for_each = {
    for s in ["linkerd"] :
    s => s
    if var.linkerd_enabled
  }

  chart         = "oci://ghcr.io/xenitab/helm-charts/linkerd-crds"
  chart_name    = "linkerd-crd"
  chart_version = "2.12.2"
}

module "linkerd" {
  depends_on = [module.opa_gatekeeper, module.cert_manager_crd, module.linkerd_crd]

  for_each = {
    for s in ["linkerd"] :
    s => s
    if var.linkerd_enabled
  }

  source = "../../kubernetes/linkerd"
}

# ingress-nginx
module "ingress_nginx" {
  depends_on = [module.opa_gatekeeper, module.linkerd]

  for_each = {
    for s in ["ingress-nginx"] :
    s => s
    if var.ingress_nginx_enabled
  }

  source = "../../kubernetes/ingress-nginx"

  cloud_provider            = "azure"
  http_snippet              = var.ingress_config.http_snippet
  linkerd_enabled           = var.linkerd_enabled
  datadog_enabled           = var.datadog_enabled
  public_private_enabled    = var.ingress_config.public_private_enabled
  allow_snippet_annotations = var.ingress_config.allow_snippet_annotations
  extra_config              = var.ingress_config.extra_config
  extra_headers             = var.ingress_config.extra_headers
  external_dns_hostname     = var.external_dns_hostname

  default_certificate = {
    enabled  = true
    dns_zone = var.cert_manager_config.dns_zone[0]
  }
}

# ingress-healthz
module "ingress_healthz" {
  depends_on = [module.opa_gatekeeper, module.linkerd]

  for_each = {
    for s in ["ingress-healthz"] :
    s => s
    if var.ingress_healthz_enabled
  }

  source = "../../kubernetes/ingress-healthz"

  environment            = var.environment
  dns_zone               = var.cert_manager_config.dns_zone[0]
  location_short         = var.location_short
  linkerd_enabled        = var.linkerd_enabled
  public_private_enabled = var.ingress_config.public_private_enabled
}

# External DNS
module "external_dns" {
  depends_on = [module.opa_gatekeeper, module.aad_pod_identity_crd]

  for_each = {
    for s in ["external-dns"] :
    s => s
    if var.external_dns_enabled
  }

  source = "../../kubernetes/external-dns"

  dns_provider = "azure"
  txt_owner_id = "${var.environment}-${var.location_short}-${var.name}${local.aks_name_suffix}"
  azure_config = {
    tenant_id       = data.azurerm_client_config.current.tenant_id
    subscription_id = data.azurerm_client_config.current.subscription_id
    resource_group  = data.azurerm_resource_group.global.name
    client_id       = var.external_dns_config.client_id
    resource_id     = var.external_dns_config.resource_id
  }
}

# Cert Manager
module "cert_manager_crd" {
  source = "../../kubernetes/helm-crd"

  chart_repository = "https://charts.jetstack.io"
  chart_name       = "cert-manager"
  chart_version    = "v1.7.1"
  values = {
    "installCRDs" = "true"
  }
}

module "cert_manager" {
  depends_on = [module.opa_gatekeeper, module.cert_manager_crd]

  for_each = {
    for s in ["cert-manager"] :
    s => s
    if var.cert_manager_enabled
  }

  source = "../../kubernetes/cert-manager"

  notification_email = var.cert_manager_config.notification_email
  cloud_provider     = "azure"
  azure_config = {
    hosted_zone_names   = var.cert_manager_config.dns_zone
    resource_group_name = data.azurerm_resource_group.global.name
    subscription_id     = data.azurerm_client_config.current.subscription_id
    client_id           = var.external_dns_config.client_id
    resource_id         = var.external_dns_config.resource_id
  }
}

# Velero
module "velero" {
  depends_on = [module.opa_gatekeeper]

  for_each = {
    for s in ["velero"] :
    s => s
    if var.velero_enabled
  }

  source = "../../kubernetes/velero"

  cloud_provider = "azure"
  azure_config = {
    subscription_id           = data.azurerm_client_config.current.subscription_id
    resource_group            = data.azurerm_resource_group.this.name
    storage_account_name      = var.velero_config.azure_storage_account_name
    storage_account_container = var.velero_config.azure_storage_account_container
    client_id                 = var.velero_config.identity.client_id
    resource_id               = var.velero_config.identity.resource_id
  }
}

# csi-secrets-store-provider-azure
module "csi_secrets_store_provider_azure_crd" {
  source = "../../kubernetes/helm-crd"

  chart_repository = "https://azure.github.io/secrets-store-csi-driver-provider-azure/charts"
  chart_name       = "csi-secrets-store-provider-azure"
  chart_version    = "1.0.1"
}

module "csi_secrets_store_provider_azure" {
  depends_on = [module.opa_gatekeeper, module.csi_secrets_store_provider_azure_crd]

  for_each = {
    for s in ["csi-secrets-store-provider-azure"] :
    s => s
    if var.csi_secrets_store_provider_azure_enabled
  }

  source = "../../kubernetes/csi-secrets-store-provider-azure"
}

# datadog
module "datadog_crd" {
  source = "../../kubernetes/helm-crd"

  chart_repository = "https://helm.datadoghq.com"
  chart_name       = "datadog-operator"
  chart_version    = "0.8.0"
}

module "datadog" {
  depends_on = [module.opa_gatekeeper, module.datadog_crd]

  for_each = {
    for s in ["datadog"] :
    s => s
    if var.datadog_enabled
  }

  source = "../../kubernetes/datadog"

  location          = var.location_short
  environment       = var.environment
  datadog_site      = var.datadog_config.datadog_site
  api_key           = var.datadog_config.api_key
  app_key           = var.datadog_config.app_key
  namespace_include = var.datadog_config.namespaces
}

# grafana-agent
module "grafana_agent_crd" {
  source = "../../kubernetes/helm-crd"

  chart_repository = "https://grafana.github.io/helm-charts"
  chart_name       = "grafana-agent-operator"
  chart_version    = "0.1.5"
}

module "grafana_agent" {
  depends_on = [module.opa_gatekeeper, module.grafana_agent_crd]

  for_each = {
    for s in ["grafana-agent"] :
    s => s
    if var.grafana_agent_enabled
  }

  source = "../../kubernetes/grafana-agent"

  remote_write_urls = {
    metrics = var.grafana_agent_config.remote_write_urls.metrics
    logs    = var.grafana_agent_config.remote_write_urls.logs
    traces  = var.grafana_agent_config.remote_write_urls.traces
  }

  credentials = {
    metrics_username = var.grafana_agent_config.credentials.metrics_username
    metrics_password = var.grafana_agent_config.credentials.metrics_password
    logs_username    = var.grafana_agent_config.credentials.logs_username
    logs_password    = var.grafana_agent_config.credentials.logs_password
    traces_username  = var.grafana_agent_config.credentials.traces_username
    traces_password  = var.grafana_agent_config.credentials.traces_password
  }

  cluster_name            = "${var.name}${local.aks_name_suffix}"
  environment             = var.environment
  vpa_enabled             = var.vpa_enabled
  namespace_include       = var.namespaces[*].name
  extra_namespaces        = var.grafana_agent_config.extra_namespaces
  include_kubelet_metrics = var.grafana_agent_config.include_kubelet_metrics
}

# falco
module "falco" {
  depends_on = [module.opa_gatekeeper]

  for_each = {
    for s in ["falco"] :
    s => s
    if var.falco_enabled
  }

  source = "../../kubernetes/falco"

  cloud_provider = "azure"
}

# Reloader
module "reloader" {
  depends_on = [module.opa_gatekeeper]

  for_each = {
    for s in ["reloader"] :
    s => s
    if var.reloader_enabled
  }

  source = "../../kubernetes/reloader"
}

# azad-kube-proxy
module "azad_kube_proxy" {
  depends_on = [module.ingress_nginx]

  for_each = {
    for s in ["azad-kube-proxy"] :
    s => s
    if var.azad_kube_proxy_enabled
  }

  source = "../../kubernetes/azad-kube-proxy"

  fqdn                  = var.azad_kube_proxy_config.fqdn
  azure_ad_group_prefix = "${var.group_name_prefix}${var.group_name_separator}${var.subscription_name}${var.group_name_separator}${var.environment}${var.group_name_separator}"
  allowed_ips           = var.azad_kube_proxy_config.allowed_ips

  azure_ad_app = {
    client_id     = var.azad_kube_proxy_config.azure_ad_app.client_id
    client_secret = var.azad_kube_proxy_config.azure_ad_app.client_secret
    tenant_id     = var.azad_kube_proxy_config.azure_ad_app.tenant_id
  }
}

# Prometheus
module "prometheus_crd" {
  source = "../../kubernetes/helm-crd"

  chart_repository = "https://prometheus-community.github.io/helm-charts"
  chart_name       = "kube-prometheus-stack"
  chart_version    = "42.1.1"
}

module "prometheus" {
  depends_on = [module.opa_gatekeeper, module.prometheus_crd]

  for_each = {
    for s in ["prometheus"] :
    s => s
    if var.prometheus_enabled
  }

  source = "../../kubernetes/prometheus"

  cloud_provider = "azure"
  azure_config = {
    azure_key_vault_name = var.prometheus_config.azure_key_vault_name
    identity = {
      client_id   = var.prometheus_config.identity.client_id
      resource_id = var.prometheus_config.identity.resource_id
      tenant_id   = var.prometheus_config.identity.tenant_id
    }
  }

  cluster_name = "${var.name}${local.aks_name_suffix}"
  environment  = var.environment
  tenant_id    = var.prometheus_config.tenant_id
  region       = var.location_short


  remote_write_authenticated = var.prometheus_config.remote_write_authenticated
  remote_write_url           = var.prometheus_config.remote_write_url

  volume_claim_storage_class_name = var.prometheus_volume_claim_storage_class_name
  volume_claim_size               = var.prometheus_config.volume_claim_size

  resource_selector  = var.prometheus_config.resource_selector
  namespace_selector = var.prometheus_config.namespace_selector

  falco_enabled                            = var.falco_enabled
  opa_gatekeeper_enabled                   = var.opa_gatekeeper_enabled
  linkerd_enabled                          = var.linkerd_enabled
  flux_enabled                             = var.fluxcd_v2_enabled
  csi_secrets_store_provider_azure_enabled = var.csi_secrets_store_provider_azure_enabled
  aad_pod_identity_enabled                 = var.aad_pod_identity_enabled
  azad_kube_proxy_enabled                  = var.azad_kube_proxy_enabled
  starboard_enabled                        = var.starboard_enabled
  vpa_enabled                              = var.vpa_enabled
  node_local_dns_enabled                   = var.node_local_dns_enabled
  grafana_agent_enabled                    = var.grafana_agent_enabled
  promtail_enabled                         = var.promtail_enabled
}

module "control_plane_logs" {
  depends_on = [module.opa_gatekeeper]

  for_each = {
    for s in ["control_plane_logs"] :
    s => s
    if var.control_plane_logs_enabled
  }

  source = "../../kubernetes/control-plane-logs"

  cloud_provider = "azure"
  azure_config = {
    azure_key_vault_name = var.control_plane_logs_config.azure_key_vault_name
    identity = {
      client_id   = var.control_plane_logs_config.identity.client_id
      resource_id = var.control_plane_logs_config.identity.resource_id
      tenant_id   = var.control_plane_logs_config.identity.tenant_id
    }
    eventhub_hostname = var.control_plane_logs_config.eventhub_hostname
    eventhub_name     = var.control_plane_logs_config.eventhub_name
  }
}

module "promtail" {
  depends_on = [module.opa_gatekeeper]

  for_each = {
    for s in ["promtail"] :
    s => s
    if var.promtail_enabled
  }

  source              = "../../kubernetes/promtail"
  cloud_provider      = "azure"
  cluster_name        = "${var.name}${local.aks_name_suffix}"
  environment         = var.environment
  region              = var.location_short
  excluded_namespaces = var.promtail_config.excluded_namespaces

  loki_address = var.promtail_config.loki_address
  azure_config = {
    azure_key_vault_name = var.promtail_config.azure_key_vault_name
    identity             = var.promtail_config.identity
  }
}

# starboard
module "starboard_crd" {
  source = "../../kubernetes/helm-crd"

  chart_repository = "https://aquasecurity.github.io/helm-charts/"
  chart_name       = "starboard-operator"
  chart_version    = "0.9.1"
}

module "starboard" {
  depends_on = [module.opa_gatekeeper, module.starboard_crd]

  for_each = {
    for s in ["starboard"] :
    s => s
    if var.starboard_enabled
  }

  source = "../../kubernetes/starboard"

  cloud_provider                  = "azure"
  client_id                       = var.starboard_config.client_id
  resource_id                     = var.starboard_config.resource_id
  volume_claim_storage_class_name = var.starboard_volume_claim_storage_class_name
}

# vpa
module "vpa_crd" {
  source = "../../kubernetes/helm-crd"

  chart_repository = "https://charts.fairwinds.com/stable"
  chart_name       = "vpa"
  chart_version    = "0.5.0"
}

module "vpa" {
  depends_on = [module.opa_gatekeeper, module.vpa_crd]

  for_each = {
    for s in ["vpa"] :
    s => s
    if var.vpa_enabled
  }

  source = "../../kubernetes/vpa"
}

# node-local-dns
module "node_local_dns" {
  depends_on = [module.opa_gatekeeper]

  for_each = {
    for s in ["node-local-dns"] :
    s => s
    if var.node_local_dns_enabled
  }

  source = "../../kubernetes/node-local-dns"
}

module "node_ttl" {
  depends_on = [module.opa_gatekeeper]

  for_each = {
    for s in ["node-ttl"] :
    s => s
    if var.node_ttl_enabled
  }

  source = "../../kubernetes/node-ttl"
}
