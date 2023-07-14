# Configure Terraform
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.7.0"
    }

    aws = {
  version = "5.7.0"
  
  }

  }
}

provider "aws" {
  region     = "us-east-1"

  }



## terrafrom variable. when set to true, the output of sensative data will be hidden from consol and the terrafrom show command. 
#When set to false, sensative data is exposed. 
variable "is_sensitive" {
  description = "is the data output sensitive"
  type        = bool
  default     = true
}





## declare a data source for aws secrects manager for azuretkcreds
data "aws_secretsmanager_secret" "secrets" {
  arn = var.sysdata.awsarn1.name
}

data "aws_secretsmanager_secret_version" "current" {
  secret_id = data.aws_secretsmanager_secret.secrets.id
}

## declare a data source for aws secrects manager for azure_token
data "aws_secretsmanager_secret" "secrets_azure_token" {
  arn = var.sysdata.awsarn2.name
}

data "aws_secretsmanager_secret_version" "current_azure_token" {
  secret_id  = data.aws_secretsmanager_secret.secrets_azure_token.id
}




## Run a .sh script to obtain a azure token
data "external" "getazuretoken" {
  program = ["bash", "/path/to/scripts/getazuretoken.sh", "${local.azure_clientid}", "${local.azure_secret}", "${local.mask_data}"]
}


output "sensitive_output" {
  value     = data.external.getazuretoken.result
  sensitive = true
}

locals {
  mask_data = var.is_sensitive ? true : false
  azure_token =  var.is_sensitive ? jsondecode(sensitive(data.aws_secretsmanager_secret_version.current_azure_token.secret_string)).azure_token : jsondecode(nonsensitive(data.aws_secretsmanager_secret_version.current_azure_token.secret_string)).azure_token
  azure_clientid  =  var.is_sensitive ? jsondecode(sensitive(data.aws_secretsmanager_secret_version.current.secret_string)).client_id : jsondecode(nonsensitive(data.aws_secretsmanager_secret_version.current.secret_string)).client_id
  azure_secret  = var.is_sensitive ?  jsondecode(sensitive(data.aws_secretsmanager_secret_version.current.secret_string)).client_secret : jsondecode(nonsensitive(data.aws_secretsmanager_secret_version.current.secret_string)).client_secret
  azure_tenantid  = var.is_sensitive ?  jsondecode(sensitive(data.aws_secretsmanager_secret_version.current.secret_string)).tenant_id : jsondecode(nonsensitive(data.aws_secretsmanager_secret_version.current.secret_string)).tenant_id
  
}



# Configure the Azure Active Directory Provider
provider "azuread" {
  
  client_id     = local.azure_clientid
  client_secret = local.azure_secret
  tenant_id = local.azure_tenantid
}


data "azuread_client_config" "current" {}

## create a new Azure App Registration
resource "azuread_application" "newapp" {
  for_each = var.apps
  display_name = each.value["name"]
  template_id  = "8adf8e6e-67b2-4cf2-a259-e3dc5476c621"
  feature_tags {
    custom_single_sign_on = true
  }
  

}

## create a new Azure service principal which will be used as a Enterprise app
resource "azuread_service_principal" "sp" {
  ## the below for_each loops through the created resources from azuread_application.newapp
  ## I can also refrence another for_each againts another source like this. var.apps[each.key].internalurl This allos me to use values from multiple sources for this resource. 
  for_each = azuread_application.newapp
  application_id                = each.value.application_id
  owners                        = [data.azuread_client_config.current.object_id]
  use_existing   = true
  preferred_single_sign_on_mode = "saml"
  #identifier_uris                     = "https://test-sb.com"
  feature_tags {
    enterprise     = true
    gallery        = false 
    custom_single_sign_on = true
  }

  ## Call grap API for the new regsitered application to update the
   provisioner "local-exec" {
      command = <<EOF
      curl --location --request PATCH 'https://graph.microsoft.com/beta/applications/${each.value.object_id}' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer ${local.azure_token}' \
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



 provisioner "local-exec" {
      command = <<EOF
      curl --location --request PUT 'https://graph.microsoft.com/beta/applications/${each.value.object_id}/connectorGroup/$ref' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer ${local.azure_token}' \
--data-raw '{
  "@odata.id": "https://graph.microsoft.com/beta/onPremisesPublishingProfiles/applicationproxy/connectorGroups/${var.apps[each.key].connector.id}"
}'
    EOF

  }





    depends_on = [
    azuread_application.newapp
  ]

}

resource "null_resource" "app_proxy_urls" {
  for_each = var.apps
## Call the APi only when changes are made to internalurl, externalurl, or azure application proxy connector
  triggers = {
    id       = each.value.connector.id
    internal = each.value.internalurl
    external = each.value.externalurl
  }

  provisioner "local-exec" {
    command = <<-EOF
    curl --location --request PATCH 'https://graph.microsoft.com/beta/applications/${azuread_application.newapp[each.key].object_id}' \
    --header 'Content-Type: application/json' \
    --header 'Authorization: Bearer ${local.azure_token}' \
    --data '{
      "onPremisesPublishing": {
        "externalAuthenticationType": "aadPreAuthentication",
        "internalUrl": "${self.triggers.internal}",
        "externalUrl": "${self.triggers.external}",
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

  provisioner "local-exec" {
    command = <<-EOF
    curl --location --request PUT 'https://graph.microsoft.com/beta/applications/${azuread_application.newapp[each.key].object_id}/connectorGroup/$ref' \
    --header 'Content-Type: application/json' \
    --header 'Authorization: Bearer ${local.azure_token}' \
    --data-raw '{
      "@odata.id": "https://graph.microsoft.com/beta/onPremisesPublishingProfiles/applicationproxy/connectorGroups/${self.triggers.id}"
    }'
    EOF
  }

  depends_on = [
    azuread_application.newapp,
    azuread_service_principal.sp,
  ]
}
