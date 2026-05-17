// =============================================================
// main.bicep — Full Infrastructure for React + Spring Boot + SQL
// Deploy: az deployment group create -g RG -f main.bicep -p main.bicepparam
// =============================================================

targetScope = 'resourceGroup'

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('SQL Server administrator login')
param sqlAdminLogin string = 'sqladmin'

@description('SQL Server administrator password')
@secure()
param sqlAdminPassword string

@description('CORS allowed origin for backend (frontend URL)')
param corsAllowedOrigin string = 'https://emp-frontend-${environment}.azurewebsites.net'

// ── Naming Convention Variables ──────────────────────────────
var prefix = 'emp'
var suffix = uniqueString(resourceGroup().id)

var names = {
  frontendApp:  '${prefix}-frontend-${environment}'
  backendApp:   '${prefix}-api-${environment}'
  frontendPlan: 'asp-frontend-${environment}'
  backendPlan:  'asp-api-${environment}'
  sqlServer:    '${prefix}-sql-${environment}-${take(suffix, 6)}'
  sqlDatabase:  '${prefix}-db-${environment}'
  keyVault:     'kv-${prefix}-${environment}-${take(suffix, 6)}'
  appInsights:  'appi-${prefix}-${environment}'
  logWorkspace: 'law-${prefix}-${environment}'
  vnet:         'vnet-${prefix}-${environment}'
}

// ── Log Analytics Workspace ──────────────────────────────────
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: names.logWorkspace
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ── Application Insights ─────────────────────────────────────
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: names.appInsights
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ── Azure SQL Server ─────────────────────────────────────────
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: names.sqlServer
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// Allow Azure services to reach SQL Server
resource sqlFirewallAzure 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ── Azure SQL Database ───────────────────────────────────────
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: names.sqlDatabase
  location: location
  sku: {
    name: environment == 'prod' ? 'S1' : 'Basic'
    tier: environment == 'prod' ? 'Standard' : 'Basic'
    capacity: environment == 'prod' ? 20 : 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: environment == 'prod' ? 53687091200 : 2147483648
    zoneRedundant: false
    requestedBackupStorageRedundancy: 'Local'
  }
}

// ── Key Vault ────────────────────────────────────────────────
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: names.keyVault
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enableRbacAuthorization: true  // Use RBAC not access policies
    publicNetworkAccess: 'Enabled'
  }
}

// Store SQL connection details as Key Vault secrets
resource kvSecretSqlUrl 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AzureSqlUrl'
  properties: {
    value: 'jdbc:sqlserver://${sqlServer.properties.fullyQualifiedDomainName}:1433;database=${names.sqlDatabase};encrypt=true;trustServerCertificate=false;loginTimeout=30'
  }
}

resource kvSecretSqlUser 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AzureSqlUsername'
  properties: { value: sqlAdminLogin }
}

resource kvSecretSqlPass 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AzureSqlPassword'
  properties: { value: sqlAdminPassword }
}

resource kvSecretAppInsights 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AppInsightsConnectionString'
  properties: { value: appInsights.properties.ConnectionString }
}

// ── App Service Plans ────────────────────────────────────────
resource frontendPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: names.frontendPlan
  location: location
  sku: {
    name: environment == 'prod' ? 'S1' : 'B1'
    tier: environment == 'prod' ? 'Standard' : 'Basic'
  }
  kind: 'linux'
  properties: { reserved: true }
}

resource backendPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: names.backendPlan
  location: location
  sku: {
    name: environment == 'prod' ? 'S2' : 'B1'
    tier: environment == 'prod' ? 'Standard' : 'Basic'
  }
  kind: 'linux'
  properties: { reserved: true }
}

// ── Backend App Service (Spring Boot) ───────────────────────
resource backendApp 'Microsoft.Web/sites@2023-01-01' = {
  name: names.backendApp
  location: location
  identity: { type: 'SystemAssigned' }  // Managed Identity for Key Vault
  properties: {
    serverFarmId: backendPlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'JAVA|17-java17'
      alwaysOn: environment != 'dev'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      cors: {
        allowedOrigins: [corsAllowedOrigin]
        supportCredentials: false
      }
      appSettings: [
        { name: 'SPRING_PROFILES_ACTIVE',               value: 'azure' }
        { name: 'AZURE_SQL_URL',                         value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=AzureSqlUrl)' }
        { name: 'AZURE_SQL_USERNAME',                    value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=AzureSqlUsername)' }
        { name: 'AZURE_SQL_PASSWORD',                    value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=AzureSqlPassword)' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=AppInsightsConnectionString)' }
        { name: 'CORS_ALLOWED_ORIGINS',                  value: corsAllowedOrigin }
        { name: 'WEBSITES_PORT',                         value: '8080' }
        { name: 'PORT',                                  value: '8080' }
      ]
    }
  }
}

// ── Frontend App Service (React) ─────────────────────────────
resource frontendApp 'Microsoft.Web/sites@2023-01-01' = {
  name: names.frontendApp
  location: location
  properties: {
    serverFarmId: frontendPlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      alwaysOn: environment != 'dev'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        { name: 'REACT_APP_API_URL', value: 'https://${backendApp.properties.defaultHostName}/api' }
        { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '18' }
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT', value: 'false' }
      ]
    }
  }
}

// ── RBAC: Grant Backend Managed Identity Key Vault Secrets Reader ──
var kvSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, backendApp.id, kvSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsUserRoleId)
    principalId: backendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Outputs ──────────────────────────────────────────────────
output frontendUrl string = 'https://${frontendApp.properties.defaultHostName}'
output backendUrl  string = 'https://${backendApp.properties.defaultHostName}'
output sqlServer   string = sqlServer.properties.fullyQualifiedDomainName
output keyVault    string = keyVault.name
output appInsights string = appInsights.name
