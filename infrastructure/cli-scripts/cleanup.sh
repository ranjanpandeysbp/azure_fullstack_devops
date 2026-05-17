#!/bin/bash
# cleanup.sh — Delete all resources to stop billing
# Usage: bash cleanup.sh [dev|staging|prod]
ENV=${1:-dev}
RG="rg-emp-${ENV}"
echo "⚠️  About to delete ALL resources in: $RG"
read -p "Type the resource group name to confirm: " CONFIRM
if [ "$CONFIRM" = "$RG" ]; then
  echo "Deleting $RG and all resources inside..."
  az group delete --name $RG --yes --no-wait
  echo "✅ Deletion initiated (runs in background)"
else
  echo "❌ Cancelled. Names didn't match."
fi
