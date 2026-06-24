@description('Azure region.')
param location string = resourceGroup().location

@description('Deterministic seed for resource names. Pass from main deployment to keep names stable across reruns.')
param resourceNameSeed string

@description('Common tags applied to all resources.')
param tags object = {}

@description('Container Registry SKU. Basic is sufficient for a single-workspace PoC.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param containerRegistrySku string = 'Standard'

var nameSeedSafe = toLower(replace(resourceNameSeed, '-', ''))
var containerRegistryName = toLower(take('acr${nameSeedSafe}${uniqueString(resourceGroup().id)}', 50))

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: containerRegistryName
  location: location
  tags: tags
  sku: {
    name: containerRegistrySku
  }
  properties: {
    // AML uses its workspace managed identity to pull/push images; admin user not needed.
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

output containerRegistryName string = containerRegistry.name
output containerRegistryId string = containerRegistry.id
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
