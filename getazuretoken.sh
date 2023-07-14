#!/bin/bash
# getazuretoken.sh

# Retrieve the arguments passed from Terraform
arg1="$1"
arg2="$2"





# get the azure token by passing client id, and client secrect as arguments. save the output to results

result=$(curl -X POST -d 'grant_type=client_credentials&client_id='${arg1}'&client_secret='${arg2}'&resource=https%3A%2F%2Fgraph.microsoft.com%2F' https://login.microsoftonline.com/tenantidhere/oauth2/token | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

# save the token results to a aws secrect you can read via terrafrom later. this requires the aws cli installed
aws secretsmanager update-secret --secret-id name_of_sec --secret-string "{\"azure_token\":\"$result\"}" --region us-east-1


