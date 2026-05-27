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

@description('Base name for resources (used to derive unique names).')
param baseName string = 'nicoldmro'

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
    baseName: baseName
    tags: tags
  }
}

output resourceGroupId string = rg.id
output dataLakeAccountName string = datalake.outputs.storageAccountName
output dataLakeAccountId string = datalake.outputs.storageAccountId
output dataLakePrimaryDfsEndpoint string = datalake.outputs.primaryDfsEndpoint
