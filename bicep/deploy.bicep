targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = 'ama-mro-playground'

@description('Azure region (EU for GDPR / data sovereignty).')
@allowed([
  'francecentral'
  'westeurope'
  'northeurope'
])
param location string = 'francecentral'

@description('Deterministic seed used to build resource names across modules. Includes MMdd from deploy time; pin an explicit value to keep re-deploy idempotent across days.')
param resourceNameSeed string = 'amamrodeve${utcNow('MMdd')}'

@description('Microsoft Entra object ID of the user running the deployment. This principal will receive Storage Blob Data Contributor on the Data Lake account.')
param deployerObjectId string = '6e94d310-1194-469a-af8e-bd502dcf2782' // get from `az ad signed-in-user show --query id -o tsv`

@description('Microsoft Entra UPN of the deployer. Used to grant the deployer PostgreSQL Entra admin.')
param deployerPrincipalName string = 'nicold_microsoft.com#EXT#@MngEnvMCAP361336.onmicrosoft.com' // get from `az ad signed-in-user show --query userPrincipalName -o tsv`

@description('Deploy the PostgreSQL Flexible Server (application/metadata store).')
param deployPostgres bool = true

@description('Deploy the Container Apps environment with backend API and frontend SPA.')
param deployContainerApps bool = true

@description('PostgreSQL administrator password. Pass at deploy time (e.g. --parameters postgresAdminPassword=...); do not commit.')
@secure()
param postgresAdminPassword string = 'passgres123'

@description('Common tags applied to all resources.')
param tags object = {
  workload: 'mro-intelligence'
  environment: 'dev'
  owner: 'nicola delfino and his agents crew'
  costCenter: 'mro-data'
}

// 1. Resource group
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// 2. Data Lake (ADLS Gen2) via dedicated module
module datalake 'deploy-datalake.bicep' = {
  name: 'deploy-datalake'
  scope: rg
  params: {
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
  }
}

// 3. RBAC on current user for the Data Lake storage account
module currentUser 'current-user.bicep' = {
  name: 'current-user'
  scope: rg
  params: {
    deployerObjectId: deployerObjectId
    storageAccountName: datalake.outputs.storageAccountName
  }
}

// 4. ML + Monitoring platform
module mlplatform 'deploy-ml.bicep' = {
  name: 'deploy-ml'
  scope: rg
  params: {
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
  }
}

// 5. RBAC on current user for the AML workspace storage account
module currentUserMlStorage 'current-user.bicep' = {
  name: 'current-user-ml-storage'
  scope: rg
  params: {
    deployerObjectId: deployerObjectId
    storageAccountName: mlplatform.outputs.mlWorkspaceStorageAccountName
    grantFilePrivilegedContributor: true
  }
}

// 6. Managed identity used by the backend to reach PostgreSQL passwordless (Entra auth)
module backendIdentity 'deploy-identity.bicep' = {
  name: 'deploy-identity'
  scope: rg
  params: {
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
  }
}

// 7. PostgreSQL Flexible Server (small PoC SKU, Entra-only auth)
module postgres 'deploy-postgres.bicep' = if (deployPostgres) {
  name: 'deploy-postgres'
  scope: rg
  params: {
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
    administratorLoginPassword: postgresAdminPassword
    entraAdminObjectId: backendIdentity.outputs.principalId
    entraAdminPrincipalName: backendIdentity.outputs.identityName
    additionalEntraAdminObjectId: deployerObjectId
    additionalEntraAdminPrincipalName: deployerPrincipalName
  }
}

// 8. Container Apps environment hosting the backend API and the frontend SPA
module containerApps 'deploy-containerapps.bicep' = if (deployContainerApps) {
  name: 'deploy-containerapps'
  scope: rg
  params: {
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
    logAnalyticsWorkspaceName: mlplatform.outputs.logAnalyticsWorkspaceName
    backendUserAssignedIdentityId: backendIdentity.outputs.identityResourceId
    backendUserAssignedIdentityClientId: backendIdentity.outputs.clientId
    postgresFqdn: deployPostgres ? postgres.?outputs.postgresFqdn ?? '' : ''
    postgresDatabaseName: deployPostgres ? postgres.?outputs.postgresDatabaseName ?? '' : ''
    postgresUser: backendIdentity.outputs.identityName
  }
}

output resourceGroupId string = rg.id
output dataLakeAccountName string = datalake.outputs.storageAccountName
output dataLakeAccountId string = datalake.outputs.storageAccountId
output dataLakePrimaryDfsEndpoint string = datalake.outputs.primaryDfsEndpoint
output currentUserBlobDataContributorRoleAssignmentId string = currentUser.outputs.storageBlobDataContributorRoleAssignmentId
output mlWorkspaceStorageBlobDataContributorRoleAssignmentId string = currentUserMlStorage.outputs.storageBlobDataContributorRoleAssignmentId
output mlWorkspaceName string = mlplatform.outputs.mlWorkspaceName
output mlOnlineEndpointName string = mlplatform.outputs.mlOnlineEndpointName
output keyVaultName string = mlplatform.outputs.keyVaultName
output applicationInsightsName string = mlplatform.outputs.applicationInsightsName
output logAnalyticsWorkspaceName string = mlplatform.outputs.logAnalyticsWorkspaceName
output mlWorkspaceStorageAccountName string = mlplatform.outputs.mlWorkspaceStorageAccountName
output postgresServerName string = deployPostgres ? postgres.?outputs.postgresServerName ?? '' : ''
output postgresFqdn string = deployPostgres ? postgres.?outputs.postgresFqdn ?? '' : ''
output postgresDatabaseName string = deployPostgres ? postgres.?outputs.postgresDatabaseName ?? '' : ''
output containerAppsEnvironmentName string = deployContainerApps ? containerApps.?outputs.containerAppsEnvironmentName ?? '' : ''
output backendApiFqdn string = deployContainerApps ? containerApps.?outputs.backendFqdn ?? '' : ''
output frontendSpaFqdn string = deployContainerApps ? containerApps.?outputs.frontendFqdn ?? '' : ''
