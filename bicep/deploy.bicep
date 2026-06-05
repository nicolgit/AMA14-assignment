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

@description('Deterministic seed used to build resource names across modules. Use a stable value to make re-deploy idempotent.')
param resourceNameSeed string = 'ama14mrodev05'

@description('Microsoft Entra object ID of the user running the deployment. This principal will receive Storage Blob Data Contributor on both storage accounts.')
param deployerObjectId string = '6e94d310-1194-469a-af8e-bd502dcf2782' // get from `az ad signed-in-user show --query id -o tsv`

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
    deployerObjectId: deployerObjectId
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
  }
}

// 3. ML + Monitoring platform
module mlplatform 'deploy-ml-platform.bicep' = {
  name: 'deploy-ml-platform'
  scope: rg
  params: {
    deployerObjectId: deployerObjectId
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
  }
}

output resourceGroupId string = rg.id
output dataLakeAccountName string = datalake.outputs.storageAccountName
output dataLakeAccountId string = datalake.outputs.storageAccountId
output dataLakePrimaryDfsEndpoint string = datalake.outputs.primaryDfsEndpoint
output mlWorkspaceName string = mlplatform.outputs.mlWorkspaceName
output mlComputeClusterName string = mlplatform.outputs.mlComputeClusterName
output mlOnlineEndpointName string = mlplatform.outputs.mlOnlineEndpointName
output keyVaultName string = mlplatform.outputs.keyVaultName
output applicationInsightsName string = mlplatform.outputs.applicationInsightsName
output logAnalyticsWorkspaceName string = mlplatform.outputs.logAnalyticsWorkspaceName
output mlWorkspaceStorageAccountName string = mlplatform.outputs.mlWorkspaceStorageAccountName
