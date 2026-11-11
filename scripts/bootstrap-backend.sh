#!/usr/bin/env bash
# One-time setup: creates the storage account that holds the Terraform state.
# Run it yourself after `az login`. Usage: ./scripts/bootstrap-backend.sh [location]
set -euo pipefail

LOCATION="${1:-polandcentral}"
RESOURCE_GROUP="rg-tfstate"
STORAGE_ACCOUNT="sttfstate$(openssl rand -hex 4)"
CONTAINER="tfstate"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none

# Keep old versions of the state so a bad apply can be recovered from.
az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-versioning true \
  --output none

az storage container create \
  --name "$CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login \
  --output none 2>/dev/null ||
  az storage container create \
    --name "$CONTAINER" \
    --account-name "$STORAGE_ACCOUNT" \
    --output none

echo
echo "Done. Put these values in azure-pipelines.yml:"
echo "  tfStateResourceGroup:  $RESOURCE_GROUP"
echo "  tfStateStorageAccount: $STORAGE_ACCOUNT"
echo "  tfStateContainer:      $CONTAINER"
