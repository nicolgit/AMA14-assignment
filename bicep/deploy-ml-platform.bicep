@description('Azure region.')
param location string = resourceGroup().location

@description('Deterministic seed for resource names. Pass from main deployment to keep names stable across reruns.')
param resourceNameSeed string

@description('Common tags applied to all resources.')
param tags object = {}

@description('Storage account SKU for Azure ML workspace default storage.')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
])
param mlWorkspaceStorageSku string = 'Standard_LRS'

@description('Azure ML training cluster VM size.')
param trainingVmSize string = 'Standard_DS3_v2'

@description('Minimum nodes for AML compute cluster.')
@minValue(0)
param trainingClusterMinNodes int = 0

@description('Maximum nodes for AML compute cluster.')
@minValue(1)
param trainingClusterMaxNodes int = 2

var nameSeedSafe = toLower(replace(resourceNameSeed, '-', ''))
var keyVaultName = toLower(take('kv-${resourceNameSeed}', 24))
var appInsightsName = take('appi-${resourceNameSeed}', 60)
var logAnalyticsName = take('law-${resourceNameSeed}', 63)
var mlWorkspaceName = take('mlw-${resourceNameSeed}', 33)
var mlEndpointName = toLower(take('rul-${resourceNameSeed}', 32))
var mlWorkspaceStorageName = toLower(take('stml${nameSeedSafe}', 24))

resource mlWorkspaceStorage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: mlWorkspaceStorageName
  location: location
  tags: tags
  sku: {
    name: mlWorkspaceStorageSku
  }
  kind: 'StorageV2'
  properties: {
    // AML workspace default storage must not have HNS enabled.
    isHnsEnabled: false
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
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

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    DisableIpMasking: false
    Request_Source: 'IbizaWebAppExtensionCreate'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableRbacAuthorization: true
    softDeleteRetentionInDays: 90
    enableSoftDelete: true
    enablePurgeProtection: false
    publicNetworkAccess: 'Enabled'
  }
}

resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: mlWorkspaceName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: mlWorkspaceName
    applicationInsights: applicationInsights.id
    keyVault: keyVault.id
    storageAccount: mlWorkspaceStorage.id
    publicNetworkAccess: 'Enabled'
  }
}

resource trainingCluster 'Microsoft.MachineLearningServices/workspaces/computes@2024-04-01' = {
  name: 'cpu-cluster'
  parent: mlWorkspace
  location: location
  properties: {
    computeType: 'AmlCompute'
    disableLocalAuth: false
    properties: {
      vmSize: trainingVmSize
      // For public AML workspace deployments, compute nodes must keep public IP enabled.
      enableNodePublicIp: true
      remoteLoginPortPublicAccess: 'Disabled'
      scaleSettings: {
        minNodeCount: trainingClusterMinNodes
        maxNodeCount: trainingClusterMaxNodes
        nodeIdleTimeBeforeScaleDown: 'PT300S'
      }
    }
  }
}

resource onlineEndpoint 'Microsoft.MachineLearningServices/workspaces/onlineEndpoints@2024-04-01' = {
  name: mlEndpointName
  parent: mlWorkspace
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    authMode: 'AADToken'
    publicNetworkAccess: 'Enabled'
    description: 'RUL serving endpoint for CNN-LSTM model.'
  }
}

resource mlWorkspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-law'
  scope: mlWorkspace
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output logAnalyticsWorkspaceName string = logAnalytics.name
output applicationInsightsName string = applicationInsights.name
output keyVaultName string = keyVault.name
output mlWorkspaceName string = mlWorkspace.name
output mlWorkspaceStorageAccountName string = mlWorkspaceStorage.name
output mlComputeClusterName string = trainingCluster.name
output mlOnlineEndpointName string = onlineEndpoint.name
