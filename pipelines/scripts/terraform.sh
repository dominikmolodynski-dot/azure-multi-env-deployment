#!/usr/bin/env bash
# Runs Terraform for one environment. Called from the AzureCLI@2 task with
# addSpnToEnvironment: true, which provides the service connection identity.
#
# Usage: terraform.sh <plan|apply> <dev|prod>
# Needs: TF_STATE_RESOURCE_GROUP, TF_STATE_STORAGE_ACCOUNT, TF_STATE_CONTAINER
set -euo pipefail

ACTION="$1"
ENVIRONMENT="$2"

# Hand the service connection identity to the azurerm provider and backend.
export ARM_CLIENT_ID="$servicePrincipalId"
export ARM_TENANT_ID="$tenantId"
ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export ARM_SUBSCRIPTION_ID
if [[ -n "${servicePrincipalKey:-}" ]]; then
  export ARM_CLIENT_SECRET="$servicePrincipalKey" # connection with a secret
else
  export ARM_USE_OIDC=true # workload identity federation
  export ARM_OIDC_TOKEN="$idToken"
fi

cd "$(dirname "$0")/../../terraform"

terraform init -input=false \
  -backend-config="resource_group_name=${TF_STATE_RESOURCE_GROUP}" \
  -backend-config="storage_account_name=${TF_STATE_STORAGE_ACCOUNT}" \
  -backend-config="container_name=${TF_STATE_CONTAINER}" \
  -backend-config="key=${ENVIRONMENT}.tfstate"

VAR_FILE="environments/${ENVIRONMENT}.tfvars"

case "$ACTION" in
  plan)
    terraform plan -input=false -var-file="$VAR_FILE"
    ;;
  apply)
    terraform apply -input=false -auto-approve -var-file="$VAR_FILE"
    # Expose outputs to the following pipeline steps.
    echo "##vso[task.setvariable variable=webAppName]$(terraform output -raw webapp_name)"
    echo "##vso[task.setvariable variable=webAppHostname]$(terraform output -raw webapp_hostname)"
    ;;
  *)
    echo "Unknown action: $ACTION (expected plan or apply)" >&2
    exit 1
    ;;
esac
