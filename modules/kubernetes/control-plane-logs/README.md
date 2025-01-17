# Controle plan logs

This module is used to run a small [vector](https://vector.dev/) deployment inside the cluster.
It listens to a message queue, parses the output and pushes it to stdout.

vector.toml includes the config how to connect to it's different endpoints.
Vector supports unit testing, and to verfiy it's config you can run `vector test vector.toml`.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 2.6.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.13.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.6.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.13.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.vector](https://registry.terraform.io/providers/hashicorp/helm/2.6.0/docs/resources/release) | resource |
| [kubernetes_namespace.this](https://registry.terraform.io/providers/hashicorp/kubernetes/2.13.1/docs/resources/namespace) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_config"></a> [azure\_config](#input\_azure\_config) | Azure specific configuration | <pre>object({<br>    azure_key_vault_name = string<br>    identity = object({<br>      client_id   = string<br>      resource_id = string<br>      tenant_id   = string<br>    })<br>    eventhub_hostname = string<br>    eventhub_name     = string<br>  })</pre> | <pre>{<br>  "azure_key_vault_name": "",<br>  "eventhub_hostname": "",<br>  "eventhub_name": "",<br>  "identity": {<br>    "client_id": "",<br>    "resource_id": "",<br>    "tenant_id": ""<br>  }<br>}</pre> | no |
| <a name="input_cloud_provider"></a> [cloud\_provider](#input\_cloud\_provider) | Name of cloud provider | `string` | n/a | yes |

## Outputs

No outputs.
