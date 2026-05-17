#!/bin/bash
# =============================================================
# deploy-infrastructure.sh
# Full Azure CLI deployment: Resource Group, VNet, SQL, Key Vault,
# App Services (React + Spring Boot), RBAC, App Insights
# Usage: bash deploy-infrastructure.sh [dev|staging|prod]
# =============================================================

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────
ENV=${1:-dev}
LOCATION="eastus"
PREFIX="emp"
RG="rg-${PREFIX}-${ENV}"
SUFFIX=$(echo $RANDOM | md5sum | head -c 6)

# Resource names
SQL_SERVER="${PREFIX}-sql-${ENV}-${SUFFIX}"
SQL_DB="${PREFIX}-db-${ENV}"
SQL_ADMIN="sqladmin"
KV_NAME="kv-${PREFIX}-${ENV}-${SUFFIX}"
FRONTEND_APP="${PREFIX}-frontend-${ENV}"
BACKEND_APP="${PREFIX}-api-${ENV}"
FRONTEND_PLAN="asp-frontend-${ENV}"
BACKEND_PLAN="asp-api-${ENV}"
APP_INSIGHTS="appi-${PREFIX}-${ENV}"
LOG_WS="law-${PREFIX}-${ENV}"

# Prompt for SQL password securely
read -sp "Enter SQL Admin Password (min 12 chars, upper+lower+digit+symbol): " SQL_PASS
echo ""

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Azure Full-Stack Deployment Script          ║"
echo "║  Environment : $ENV                          ║"
echo "║  Location    : $LOCATION                     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── STEP 1: Login & Select Subscription ───────────────────────
echo "[1/12] 🔐 Checking Azure login..."
az account show --output none 2>/dev/null || az login
SUB_ID=$(az account show --query id -o tsv)
echo "       Subscription: $(az account show --query name -o tsv)"

# ── STEP 2: Resource Group ────────────────────────────────────
echo "[2/12] 📁 Creating Resource Group: $RG"
az group create \
  --name $RG \
  --location $LOCATION \
  --tags Environment=$ENV Project=EmployeeManagement ManagedBy=CLI \
  --output none
echo "       ✅ Resource group created"

# ── STEP 3: Log Analytics Workspace ──────────────────────────
echo "[3/12] 📊 Creating Log Analytics Workspace: $LOG_WS"
az monitor log-analytics workspace create \
  --resource-group $RG \
  --workspace-name $LOG_WS \
  --location $LOCATION \
  --output none
LOG_WS_ID=$(az monitor log-analytics workspace show \
  --resource-group $RG \
  --workspace-name $LOG_WS \
  --query id -o tsv)
echo "       ✅ Log Analytics workspace created"

# ── STEP 4: Application Insights ─────────────────────────────
echo "[4/12] 📡 Creating Application Insights: $APP_INSIGHTS"
az monitor app-insights component create \
  --app $APP_INSIGHTS \
  --resource-group $RG \
  --location $LOCATION \
  --workspace $LOG_WS_ID \
  --output none
APPI_CONN=$(az monitor app-insights component show \
  --app $APP_INSIGHTS \
  --resource-group $RG \
  --query connectionString -o tsv)
echo "       ✅ Application Insights created"

# ── STEP 5: Azure SQL Server ──────────────────────────────────
echo "[5/12] 🗃️  Creating SQL Server: $SQL_SERVER"
az sql server create \
  --name $SQL_SERVER \
  --resource-group $RG \
  --location $LOCATION \
  --admin-user $SQL_ADMIN \
  --admin-password "$SQL_PASS" \
  --output none

# Allow Azure services
az sql server firewall-rule create \
  --resource-group $RG \
  --server $SQL_SERVER \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0 \
  --output none

# Allow your IP for initial setup
MY_IP=$(curl -s https://api.ipify.org)
az sql server firewall-rule create \
  --resource-group $RG \
  --server $SQL_SERVER \
  --name AllowMyIP \
  --start-ip-address $MY_IP \
  --end-ip-address $MY_IP \
  --output none

echo "       ✅ SQL Server created (your IP $MY_IP whitelisted)"

# ── STEP 6: SQL Database ──────────────────────────────────────
echo "[6/12] 🗃️  Creating SQL Database: $SQL_DB"
SKU=$( [ "$ENV" = "prod" ] && echo "S1" || echo "Basic" )
az sql db create \
  --resource-group $RG \
  --server $SQL_SERVER \
  --name $SQL_DB \
  --edition $( [ "$ENV" = "prod" ] && echo "Standard" || echo "Basic" ) \
  --capacity $( [ "$ENV" = "prod" ] && echo "20" || echo "5" ) \
  --output none

SQL_FQDN=$(az sql server show \
  --name $SQL_SERVER \
  --resource-group $RG \
  --query fullyQualifiedDomainName -o tsv)

SQL_URL="jdbc:sqlserver://${SQL_FQDN}:1433;database=${SQL_DB};encrypt=true;trustServerCertificate=false;loginTimeout=30"
echo "       ✅ SQL Database created"
echo "       📌 Connection: $SQL_FQDN"

# ── STEP 7: Key Vault ─────────────────────────────────────────
echo "[7/12] 🔑 Creating Key Vault: $KV_NAME"
az keyvault create \
  --name $KV_NAME \
  --resource-group $RG \
  --location $LOCATION \
  --enable-rbac-authorization true \
  --soft-delete-retention-days 7 \
  --output none

# Grant current user Key Vault Administrator role
CURRENT_USER=$(az account show --query user.name -o tsv)
KV_ID=$(az keyvault show --name $KV_NAME --resource-group $RG --query id -o tsv)

az role assignment create \
  --assignee $CURRENT_USER \
  --role "Key Vault Administrator" \
  --scope $KV_ID \
  --output none

echo "       ✅ Key Vault created"

# Store all secrets
echo "       🔐 Storing secrets in Key Vault..."
az keyvault secret set --vault-name $KV_NAME --name "AzureSqlUrl"               --value "$SQL_URL"     --output none
az keyvault secret set --vault-name $KV_NAME --name "AzureSqlUsername"          --value "$SQL_ADMIN"  --output none
az keyvault secret set --vault-name $KV_NAME --name "AzureSqlPassword"          --value "$SQL_PASS"   --output none
az keyvault secret set --vault-name $KV_NAME --name "AppInsightsConnectionString" --value "$APPI_CONN" --output none
echo "       ✅ All secrets stored"

# ── STEP 8: App Service Plans ─────────────────────────────────
echo "[8/12] ⚙️  Creating App Service Plans"

BACKEND_SKU=$( [ "$ENV" = "prod" ] && echo "S2" || echo "B1" )
FRONTEND_SKU=$( [ "$ENV" = "prod" ] && echo "S1" || echo "B1" )

az appservice plan create \
  --name $BACKEND_PLAN \
  --resource-group $RG \
  --location $LOCATION \
  --sku $BACKEND_SKU \
  --is-linux \
  --output none

az appservice plan create \
  --name $FRONTEND_PLAN \
  --resource-group $RG \
  --location $LOCATION \
  --sku $FRONTEND_SKU \
  --is-linux \
  --output none

echo "       ✅ App Service Plans created ($BACKEND_SKU / $FRONTEND_SKU)"

# ── STEP 9: Backend App Service (Spring Boot) ─────────────────
echo "[9/12] 🌿 Creating Backend App Service: $BACKEND_APP"
az webapp create \
  --resource-group $RG \
  --plan $BACKEND_PLAN \
  --name $BACKEND_APP \
  --runtime "JAVA:17-java17" \
  --output none

# Enable System-Assigned Managed Identity
az webapp identity assign \
  --resource-group $RG \
  --name $BACKEND_APP \
  --output none

BACKEND_MI=$(az webapp identity show \
  --resource-group $RG \
  --name $BACKEND_APP \
  --query principalId -o tsv)

FRONTEND_URL="https://${FRONTEND_APP}.azurewebsites.net"

# Set App Settings (Key Vault references — no secrets in config!)
az webapp config appsettings set \
  --resource-group $RG \
  --name $BACKEND_APP \
  --settings \
    SPRING_PROFILES_ACTIVE=azure \
    "AZURE_SQL_URL=@Microsoft.KeyVault(VaultName=${KV_NAME};SecretName=AzureSqlUrl)" \
    "AZURE_SQL_USERNAME=@Microsoft.KeyVault(VaultName=${KV_NAME};SecretName=AzureSqlUsername)" \
    "AZURE_SQL_PASSWORD=@Microsoft.KeyVault(VaultName=${KV_NAME};SecretName=AzureSqlPassword)" \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=@Microsoft.KeyVault(VaultName=${KV_NAME};SecretName=AppInsightsConnectionString)" \
    CORS_ALLOWED_ORIGINS=$FRONTEND_URL \
    WEBSITES_PORT=8080 \
    PORT=8080 \
  --output none

# Enable HTTPS only
az webapp update --resource-group $RG --name $BACKEND_APP --https-only true --output none

echo "       ✅ Backend App Service created"

# ── STEP 10: Frontend App Service (React) ─────────────────────
echo "[10/12] ⚛️  Creating Frontend App Service: $FRONTEND_APP"
az webapp create \
  --resource-group $RG \
  --plan $FRONTEND_PLAN \
  --name $FRONTEND_APP \
  --runtime "NODE:18-lts" \
  --output none

BACKEND_URL="https://${BACKEND_APP}.azurewebsites.net"

az webapp config appsettings set \
  --resource-group $RG \
  --name $FRONTEND_APP \
  --settings \
    REACT_APP_API_URL="${BACKEND_URL}/api" \
    WEBSITE_NODE_DEFAULT_VERSION=18 \
    SCM_DO_BUILD_DURING_DEPLOYMENT=false \
  --output none

az webapp update --resource-group $RG --name $FRONTEND_APP --https-only true --output none
echo "       ✅ Frontend App Service created"

# ── STEP 11: RBAC for Key Vault ───────────────────────────────
echo "[11/12] 🔐 Granting Backend Managed Identity access to Key Vault..."
az role assignment create \
  --assignee-object-id $BACKEND_MI \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope $KV_ID \
  --output none
echo "       ✅ RBAC role assigned (Key Vault Secrets User)"

# ── STEP 12: Summary ──────────────────────────────────────────
echo ""
echo "[12/12] 📋 Deployment Complete!"
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                  DEPLOYMENT SUMMARY                     ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║ Environment  : $ENV"
echo "║ Resource Grp : $RG"
echo "║ Frontend     : $FRONTEND_URL"
echo "║ Backend API  : $BACKEND_URL"
echo "║ SQL Server   : $SQL_FQDN"
echo "║ Key Vault    : $KV_NAME"
echo "║ App Insights : $APP_INSIGHTS"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  NEXT STEPS:                                            ║"
echo "║  1. Run the pipelines to deploy code                   ║"
echo "║  2. Test: curl $BACKEND_URL/api/health                 ║"
echo "║  3. Open: $FRONTEND_URL                                ║"
echo "╚══════════════════════════════════════════════════════════╝"
