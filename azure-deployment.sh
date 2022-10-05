#!/usr/bin/env bash
##############################################################################
# Usage: ./azure-deployment.sh
# Setup the Azure infrastructure for this project and deploys the containers.
##############################################################################

PROJECT="voting-compose"
RESOURCE_GROUP="rg-${PROJECT}"
LOCATION="eastus"
TAG=$PROJECT

LOG_ANALYTICS_WORKSPACE="log-${PROJECT}"
CONTAINERAPPS_ENVIRONMENT="env-${PROJECT}"

UNIQUE_IDENTIFIER=$(whoami)
REGISTRY="votingcompose${UNIQUE_IDENTIFIER}"

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags system="$TAG"

az monitor log-analytics workspace create \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags system="$TAG" \
  --workspace-name "$LOG_ANALYTICS_WORKSPACE"

LOG_ANALYTICS_WORKSPACE_CLIENT_ID=$(
  az monitor log-analytics workspace show \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
    --query customerId  \
    --output tsv | tr -d '[:space:]'
)
echo "LOG_ANALYTICS_WORKSPACE_CLIENT_ID=$LOG_ANALYTICS_WORKSPACE_CLIENT_ID"

LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET=$(
  az monitor log-analytics workspace get-shared-keys \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
    --query primarySharedKey \
    --output tsv | tr -d '[:space:]'
)
echo "LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET=$LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET"

az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags system="$TAG" \
  --name "$REGISTRY" \
  --workspace "$LOG_ANALYTICS_WORKSPACE" \
  --sku Premium \
  --admin-enabled true

az acr update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$REGISTRY" \
  --anonymous-pull-enabled true

REGISTRY_URL=$(
  az acr show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$REGISTRY" \
    --query "loginServer" \
    --output tsv
)

echo "REGISTRY_URL=$REGISTRY_URL"

az containerapp env create \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags system="$TAG" \
  --name "$CONTAINERAPPS_ENVIRONMENT" \
  --logs-workspace-id "$LOG_ANALYTICS_WORKSPACE_CLIENT_ID" \
  --logs-workspace-key "$LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET"

REGISTRY_USERNAME=$(
az acr credential show \
  --name "$REGISTRY" \
  --query "username" \
  --output tsv
)

echo "REGISTRY_USERNAME=$REGISTRY_USERNAME"

REGISTRY_PASSWORD=$(
  az acr credential show \
    --name "$REGISTRY" \
    --query "passwords[0].value" \
    --output tsv
)

echo "REGISTRY_PASSWORD=$REGISTRY_PASSWORD"
