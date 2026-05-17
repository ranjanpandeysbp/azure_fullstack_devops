// main.bicepparam — parameter file for main.bicep
using './main.bicep'

param environment = 'dev'
param location = 'eastus'
param sqlAdminLogin = 'sqladmin'
// sqlAdminPassword is provided securely via CI/CD or CLI --parameters flag
// NEVER commit actual passwords to source control!
param sqlAdminPassword = ''  // Override at deploy time
param corsAllowedOrigin = 'https://emp-frontend-dev.azurewebsites.net'
