@description('Azure region.')
param location string = resourceGroup().location

@description('Deterministic seed used to build resource names across modules.')
param resourceNameSeed string

@description('Common tags.')
param tags object = {}

var nameSeedSafe = toLower(replace(resourceNameSeed, '-', ''))
var identityName = toLower(take('id-backend-${nameSeedSafe}', 128))

// User-assigned managed identity shared by the backend Container App (to authenticate)
// and PostgreSQL (as the Entra administrator principal). No secrets involved.
resource backendIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

output identityResourceId string = backendIdentity.id
output identityName string = backendIdentity.name
output principalId string = backendIdentity.properties.principalId
output clientId string = backendIdentity.properties.clientId
