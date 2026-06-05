@description('Azure region.')
param location string = resourceGroup().location

@description('Deterministic seed used to build resource names across modules.')
param resourceNameSeed string

@description('Microsoft Entra object ID of the deployment user to grant Storage Blob Data Contributor on this Data Lake account.')
param deployerObjectId string

@description('Common tags.')
param tags object = {}

@description('Storage account SKU.')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageSku string = 'Standard_ZRS'

@description('Containers (ADLS Gen2 file systems) to create. Default = lakehouse zones.')
param containers array = [
  'raw'
  'canonical'
  'curated'
]

// Storage account name: lowercase, 3-24 chars, globally unique if seed is globally unique
var nameSeedSafe = toLower(replace(resourceNameSeed, '-', ''))
var storageAccountName = toLower(take('lake${nameSeedSafe}', 24))
var storageBlobDataContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true // ADLS Gen2
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled' // restrict via Private Endpoint in prod
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 30
    }
  }
}

resource lakeContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = [for name in containers: {
  parent: blobService
  name: name
  properties: {
    publicAccess: 'None'
  }
}]

resource deployerBlobDataContributorOnLake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, deployerObjectId, storageBlobDataContributorRoleDefinitionId)
  scope: storage
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinitionId
    principalId: deployerObjectId
  }
}

output storageAccountName string = storage.name
output storageAccountId string = storage.id
output primaryDfsEndpoint string = storage.properties.primaryEndpoints.dfs
output primaryBlobEndpoint string = storage.properties.primaryEndpoints.blob
output containerNames array = containers
