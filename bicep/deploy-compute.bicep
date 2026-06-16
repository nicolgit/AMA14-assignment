@description('Azure region.')
param location string = resourceGroup().location

@description('Deterministic seed for resource names. Pass from main deployment to keep names stable across reruns.')
param resourceNameSeed string

@description('Name of the existing Azure ML workspace that will host the compute instance.')
param mlWorkspaceName string

@description('Azure ML compute instance VM size.')
param trainingVmSize string = 'Standard_DS3_v2'

@description('Entra object ID of the user the compute instance is assigned to (single-user interactive resource).')
param computeInstanceAssignedUserObjectId string

var computeInstanceName = take('ci-${resourceNameSeed}', 24)

resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2024-10-01-preview' existing = {
  name: mlWorkspaceName
}

resource computeInstance 'Microsoft.MachineLearningServices/workspaces/computes@2024-04-01' = {
  name: computeInstanceName
  parent: mlWorkspace
  location: location
  properties: {
    computeType: 'ComputeInstance'
    properties: {
      vmSize: trainingVmSize
      // Single-user interactive resource: assigned to the deployer.
      applicationSharingPolicy: 'Personal'
      personalComputeInstanceSettings: {
        assignedUser: {
          objectId: computeInstanceAssignedUserObjectId
          tenantId: subscription().tenantId
        }
      }
    }
  }
}

output mlComputeInstanceName string = computeInstance.name
