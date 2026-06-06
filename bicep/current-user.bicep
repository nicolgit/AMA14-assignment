@description('Microsoft Entra object ID of the current deployment user.')
param deployerObjectId string

@description('Name of the storage account where RBAC must be assigned to the current user.')
param storageAccountName string

@description('Also grant Storage File Privileged Contributor (required for AML file datastores when shared keys are disabled).')
param grantFilePrivilegedContributor bool = false

// Built-in role definition IDs.
var storageBlobDataContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
var storageFilePrivilegedContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69566ab7-960f-475b-8e7c-b3118f30c6bd')

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource deployerBlobDataContributorOnLake 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, deployerObjectId, storageBlobDataContributorRoleDefinitionId)
  scope: storage
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleDefinitionId
    principalId: deployerObjectId
    principalType: 'User'
  }
}

// Storage File Privileged Contributor for the current user (optional, e.g. AML file datastores).
resource deployerFilePrivilegedContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (grantFilePrivilegedContributor) {
  name: guid(storage.id, deployerObjectId, storageFilePrivilegedContributorRoleDefinitionId)
  scope: storage
  properties: {
    roleDefinitionId: storageFilePrivilegedContributorRoleDefinitionId
    principalId: deployerObjectId
    principalType: 'User'
  }
}

output storageBlobDataContributorRoleAssignmentId string = deployerBlobDataContributorOnLake.id
