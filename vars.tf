variable "apps" {
    type = map(any)
    default = {
      app_1 = {
        internalurl = "https://exampleinternalurl1.com"
        externalurl = "https://externalURL1.verifiedDomain.com"
        name = "app-proxy-test1"
        connector = {
            name = "ConnectorName"
            id = "ConnectorID"
        }
       
      }
      app_2 = {
        internalurl = "https://exampleinternalurl2.com"
        externalurl = "https://externalURL2.verifiedDomain.com"
        name = "app-proxy-test2"
        connector = {
            name = "ConnectorName"
            id = "ConnectorID"
        }
       
       
      }
        app_3 = {
        internalurl = "https://exampleinternalurl3.com"
        externalurl = "https://externalURL3.verifiedDomain.com"
        name = "app-proxy-test3"
        connector = {
            name = "ConnectorName"
            id = "ConnectorID"
        }
       
       
      }

    }
}

## Variable store for arn data. I have two secrects. 1 that with key, value for azure clientid, secrect, and tenantid. 
## The other secret has a key value for azure_token = empty. this value will update each time with a new token
variable "sysdata" {
    type = map(any)
    default = {
      awsarn1 = {
        name = "arn:aws:secretsmanager:*****"
    }
      awsarn2 = {
        name = "arn:aws:secretsmanager:*****"
    }
}
}
