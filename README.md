# Advanced Terraform Techniques: Managing Azure Application Proxy with AWS Secrets and Local-Exec Provisioner

This guide explains how to leverage Terraform—an open-source Infrastructure as Code (IaC) tool—to manage Azure Application Proxy configurations, circumventing certain limitations of the `azuread` provider. Our approach employs AWS Secrets Manager, Microsoft Graph API, and the local-exec provisioner in Terraform.

## Limitations of Terraform Provider `azuread`

Despite providing substantial support for Azure Active Directory resources, the `azuread` provider does not currently support Azure Application Proxy configurations natively. Our method, which involves AWS Secrets Manager, Microsoft Graph API, and Terraform's local-exec provisioner, effectively addresses this limitation.

## Leveraging AWS Secrets Manager

Initially, AWS Secrets Manager helps to securely manage sensitive data, such as Azure client IDs, secrets, and tenant IDs. Below, you can find a code snippet that creates two data sources, `secrets` and `secrets_azure_token`, to fetch secret values stored via the AWS provider:

```hcl
data "aws_secretsmanager_secret" "secrets" {
  arn = var.sysdata.awsarn1.name
}

data "aws_secretsmanager_secret_version" "current" {
  secret_id = data.aws_secretsmanager_secret.secrets.id
}

data "aws_secretsmanager_secret" "secrets_azure_token" {
  arn = var.sysdata.awsarn2.name
}

data "aws_secretsmanager_secret_version" "current_azure_token" {
  secret_id  = data.aws_secretsmanager_secret.secrets_azure_token.id
}
```

## Executing Scripts with Local-Exec Provisioner

The local-exec provisioner is used to execute scripts and shell commands locally on the machine running Terraform. It's leveraged to call a bash script `getazuretoken.sh`, which retrieves an Azure token needed for Microsoft Graph API authentication:

```hcl
data "external" "getazuretoken" {
  program = ["bash", "/home/user/path/to/scripts/getazuretoken.sh", "${local.azure_clientid}", "${local.azure_secret}", "${local.mask_data}"]
}
```

Moreover, the local-exec provisioner executes CURL commands interacting with Microsoft Graph API to update Azure application configurations:

```hcl
provisioner "local-exec" {
  command = <<EOF
  curl --location --request PATCH 'https://graph.microsoft.com/beta/applications/${each.value.object_id}' \
  --header 'Content-Type: application/json' \
  --header 'Authorization: Bearer${local.azure_token}' \
  --data '{
    "onPremisesPublishing": {
      "externalAuthenticationType": "aadPreAuthentication",
      "internalUrl": "${var.apps[each.key].internalurl}",
      "externalUrl": "${var.apps[each.key].externalurl}",
      "isHttpOnlyCookieEnabled": true,
      "isOnPremPublishingEnabled": true,
      "isPersistentCookieEnabled": true,
      "isSecureCookieEnabled": true,
      "isStateSessionEnabled": true,
      "isTranslateHostHeaderEnabled": true,
      "isTranslateLinksInBodyEnabled": true
    }
  }'
EOF
}
```

## Securing Sensitive Data

Sensitive data is protected from exposure in logs or outputs through the introduction of a `is_sensitive` variable. If set to `true`, Azure token, client ID, secret, and tenant ID are masked:

```hcl
variable "is_sensitive" {
  description = "is the data output sensitive"
  type        = bool
  default     = true
}

locals {
  azure_token =  var.is_sensitive ? jsondecode(sensitive(data.aws_secretsmanager_secret_version.current_azure_token.secret_string)).azure_token : jsondecode(nonsensitive(data.aws_secretsmanager_secret_version.current_azure_token.secret_string)).azure_token
  azure_clientid  =  var.is_sensitive ? jsondecode(sensitive(data.aws_secretsmanager_secret_version.current.secret_string)).client_id : jsondecode(nonsensitive(data.aws_secretsmanager_secret_version.current.secret_string)).client_id
  azure_secret  = var.is_sensitive ?  jsondecode(sensitive(data.aws_secretsmanager_secret_version.current.secret_string)).client_secret : jsondecode(nonsensitive(data.aws_secretsmanager_secret_version.current.secret_string)).client_secret
  azure_tenantid  = var.is_sensitive ?  jsondecode(sensitive(data.aws_secretsmanager_secret_version.current.secret_string)).tenant_id : jsondecode(nonsensitive(data.aws_secretsmanager_secret_version.current.secret_string)).tenant_id
}
```

However, developers can disable this protection for debugging purposes by setting `is_sensitive` to `false`.

## Utilizing a Vars.tf File

A `vars.tf` file is used to define internal and external URLs for applications and the Azure proxy connectors. Acting as a centralized place for configuring variables, it enhances code maintainability. The local-exec provisioner is triggered only when there are changes in the `vars.tf` file, thus ensuring efficient resource utilization.

## The Benefits of this Workaround

1. **Fully Automated Process:** Automation of Azure Application Proxy configurations that would otherwise require manual intervention.

2. **Sensitive Data Security:** Effective management and security of sensitive data through integration with AWS Secrets Manager.

3. **Debugging Ease:** Flexibility to expose sensitive data eases debugging and issue resolution.

4. **Increased Efficiency:** The local-exec provisioner is only triggered when necessary, thus saving resources.

## Use Cases

This workaround proves valuable in scenarios such as:

1. **Hybrid Cloud Environments:** Organizations utilizing both Azure and AWS can seamlessly manage resources across both platforms.

2. **High-Security Requirements:** Applications requiring robust security measures can securely and effectively manage sensitive data.

3. **Large-Scale Deployments:** This automation can significantly reduce manual effort and human error in large environments with multiple applications.

In conclusion, while Terraform's `azuread` provider currently does not support Azure Application Proxy configurations, effective workarounds exist. Through integration with AWS Secrets Manager and utilization of the local-exec provisioner for running scripts and making Graph API calls, a comprehensive and secure infrastructure management solution can be created.
