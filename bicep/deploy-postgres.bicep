@description('Azure region.')
param location string = resourceGroup().location

@description('Deterministic seed used to build resource names across modules.')
param resourceNameSeed string

@description('Common tags.')
param tags object = {}

@description('PostgreSQL administrator login name.')
param administratorLogin string = 'pgadmin'

@description('PostgreSQL administrator password. Only used when password authentication is enabled. Pass at deploy time; do not commit.')
@secure()
param administratorLoginPassword string = ''

@description('Authentication mode. EntraOnly = Entra ID only, no secrets (default). EntraAndPassword also allows the local admin password.')
@allowed([
  'EntraOnly'
  'EntraAndPassword'
])
param authMode string = 'EntraOnly'

@description('Entra tenant ID for Entra authentication.')
param tenantId string = subscription().tenantId

@description('Object ID (principal ID) of the Entra principal to set as PostgreSQL administrator.')
param entraAdminObjectId string

@description('Display name of the Entra administrator principal (e.g. the managed identity name).')
param entraAdminPrincipalName string

@description('Type of the Entra administrator principal.')
@allowed([
  'ServicePrincipal'
  'User'
  'Group'
])
param entraAdminPrincipalType string = 'ServicePrincipal'

@description('Object ID of an additional Entra principal (e.g. the deployer user) to also set as PostgreSQL administrator. Empty = skip.')
param additionalEntraAdminObjectId string = ''

@description('Principal name of the additional Entra administrator (UPN for a user).')
param additionalEntraAdminPrincipalName string = ''

@description('Type of the additional Entra administrator principal.')
@allowed([
  'ServicePrincipal'
  'User'
  'Group'
])
param additionalEntraAdminPrincipalType string = 'User'

@description('PostgreSQL major version.')
@allowed([
  '14'
  '15'
  '16'
])
param postgresVersion string = '16'

@description('Compute SKU. PoC default = Burstable B1ms (1 vCore, 2 GB).')
param skuName string = 'Standard_B1ms'

@description('Compute tier for the SKU.')
@allowed([
  'Burstable'
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string = 'Burstable'

@description('Storage size in GB. PoC default = 32 GB (minimum).')
@allowed([
  32
  64
  128
])
param storageSizeGB int = 32

@description('Initial application database to create.')
param databaseName string = 'hangarmind'

@description('Allow other Azure services to reach the server (PoC convenience). Disable and use Private Endpoint in prod.')
param allowAzureServices bool = true

// Server name: lowercase, 3-63 chars, globally unique
var nameSeedSafe = toLower(replace(resourceNameSeed, '-', ''))
var serverName = toLower(take('pg-${nameSeedSafe}', 63))

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: union({
    version: postgresVersion
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: 'Disabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled' // single region is fine for a PoC
    }
    highAvailability: {
      mode: 'Disabled' // no HA in a PoC
    }
    network: {
      publicNetworkAccess: 'Enabled' // restrict via Private Endpoint in prod
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled' // Entra ID auth for passwordless access
      passwordAuth: authMode == 'EntraAndPassword' ? 'Enabled' : 'Disabled'
      tenantId: tenantId
    }
  }, authMode == 'EntraAndPassword' ? {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
  } : {})
}

// Entra administrator: the backend managed identity. Lets the backend connect
// passwordless using a token (no secrets stored anywhere).
// NOTE: server sub-resource operations are serialized (firewall -> entraAdmin -> database)
// because PostgreSQL rejects the Entra admin operation while the server is being
// modified concurrently (AadAuthOperationCannotBePerformedWhenServerIsNotAccessible).
resource entraAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01' = {
  parent: postgres
  name: entraAdminObjectId
  dependsOn: [
    allowAzure
  ]
  properties: {
    principalType: entraAdminPrincipalType
    principalName: entraAdminPrincipalName
    tenantId: tenantId
  }
}

// Additional Entra administrator (e.g. the deployer) so a human can run DDL/queries.
// Serialized after entraAdmin to avoid concurrent server modifications.
resource deployerAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01' = if (!empty(additionalEntraAdminObjectId) && !empty(additionalEntraAdminPrincipalName)) {
  parent: postgres
  name: additionalEntraAdminObjectId
  dependsOn: [
    entraAdmin
  ]
  properties: {
    principalType: additionalEntraAdminPrincipalType
    principalName: additionalEntraAdminPrincipalName
    tenantId: tenantId
  }
}

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgres
  name: databaseName
  dependsOn: [
    entraAdmin
    deployerAdmin
  ]
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// PoC firewall rule: allow access from Azure services (0.0.0.0 special range).
// Created first so it does not run concurrently with the Entra admin operation.
resource allowAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = if (allowAzureServices) {
  parent: postgres
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output postgresServerName string = postgres.name
output postgresServerId string = postgres.id
output postgresFqdn string = postgres.properties.fullyQualifiedDomainName
output postgresDatabaseName string = database.name
output postgresAdministratorLogin string = administratorLogin
output postgresEntraAdminName string = entraAdminPrincipalName
