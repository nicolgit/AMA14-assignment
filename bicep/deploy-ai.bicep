@description('Azure region.')
param location string = resourceGroup().location

@description('Deterministic seed used to build resource names across modules.')
param resourceNameSeed string

@description('Common tags.')
param tags object = {}

@description('Backend managed identity principal ID. Receives RBAC on AI and Search resources when provided.')
param backendPrincipalId string = ''

@description('Azure AI Services SKU for Foundry/OpenAI model deployments.')
@allowed([
  'S0'
])
param aiServicesSku string = 'S0'

@description('Azure AI Speech SKU.')
@allowed([
  'F0'
  'S0'
])
param speechSku string = 'S0'

@description('Chat model deployment name used by the application.')
param chatDeploymentName string = 'gpt-5-6-sol'

@description('Chat model name. Override at deploy time if a newer model is available in the target region.')
param chatModelName string = 'gpt-5.6-sol'

@description('Chat model version. Must be available in the selected Azure region.')
param chatModelVersion string = '2026-07-09'

@description('Deployment SKU for the chat model. GPT-5.6 Sol in France Central supports GlobalStandard and DataZoneStandard, not Standard.')
@allowed([
  'GlobalStandard'
  'DataZoneStandard'
  'Standard'
])
param chatDeploymentSku string = 'DataZoneStandard'

@description('Tokens-per-minute capacity for the chat model deployment.')
param chatDeploymentCapacity int = 10

@description('Embedding model deployment name used by ingestion and RAG.')
param embeddingDeploymentName string = 'text-embedding-3-large'

@description('Embedding model name.')
param embeddingModelName string = 'text-embedding-3-large'

@description('Embedding model version. Must be available in the selected Azure region.')
param embeddingModelVersion string = '1'

@description('Tokens-per-minute capacity for the embedding model deployment.')
param embeddingDeploymentCapacity int = 10

@description('Azure AI Search SKU for the RAG index.')
@allowed([
  'free'
  'basic'
  'standard'
  'standard2'
  'standard3'
])
param searchSku string = 'basic'

@description('Default index name expected by the Engineering Copilot ingestion/API layer.')
param searchIndexName string = 'engineering-docs'

var nameSeedSafe = toLower(replace(resourceNameSeed, '-', ''))
var uniqueSuffix = uniqueString(resourceGroup().id)
var aiServicesName = toLower(take('ai${nameSeedSafe}${uniqueSuffix}', 64))
var speechServiceName = toLower(take('spch${nameSeedSafe}${uniqueSuffix}', 64))
var searchServiceName = toLower(take('srch${nameSeedSafe}${uniqueSuffix}', 60))

var hasBackendPrincipal = !empty(backendPrincipalId)

var cognitiveServicesOpenAiUserRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
var cognitiveServicesSpeechUserRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f2dc8367-1007-4938-bd23-fe263f013447')
var searchServiceContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0')
var searchIndexDataContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7')

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiServicesName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: aiServicesSku
  }
  properties: {
    customSubDomainName: aiServicesName
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    disableLocalAuth: true
  }
}

resource chatDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiServices
  name: chatDeploymentName
  sku: {
    name: chatDeploymentSku
    capacity: chatDeploymentCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: chatModelName
      version: chatModelVersion
    }
    raiPolicyName: 'Microsoft.Default'
  }
}

resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiServices
  name: embeddingDeploymentName
  dependsOn: [
    chatDeployment
  ]
  sku: {
    name: 'Standard'
    capacity: embeddingDeploymentCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: embeddingModelName
      version: embeddingModelVersion
    }
    raiPolicyName: 'Microsoft.Default'
  }
}

resource speech 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: speechServiceName
  location: location
  tags: tags
  kind: 'SpeechServices'
  sku: {
    name: speechSku
  }
  properties: {
    customSubDomainName: speechServiceName
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    disableLocalAuth: true
  }
}

resource search 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: location
  tags: tags
  sku: {
    name: searchSku
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'
    disableLocalAuth: false
    networkRuleSet: {
      ipRules: []
    }
  }
}

resource backendOpenAiUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (hasBackendPrincipal) {
  name: guid(aiServices.id, backendPrincipalId, cognitiveServicesOpenAiUserRoleDefinitionId)
  scope: aiServices
  properties: {
    roleDefinitionId: cognitiveServicesOpenAiUserRoleDefinitionId
    principalId: backendPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource backendSpeechUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (hasBackendPrincipal) {
  name: guid(speech.id, backendPrincipalId, cognitiveServicesSpeechUserRoleDefinitionId)
  scope: speech
  properties: {
    roleDefinitionId: cognitiveServicesSpeechUserRoleDefinitionId
    principalId: backendPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource backendSearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (hasBackendPrincipal) {
  name: guid(search.id, backendPrincipalId, searchServiceContributorRoleDefinitionId)
  scope: search
  properties: {
    roleDefinitionId: searchServiceContributorRoleDefinitionId
    principalId: backendPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource backendSearchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (hasBackendPrincipal) {
  name: guid(search.id, backendPrincipalId, searchIndexDataContributorRoleDefinitionId)
  scope: search
  properties: {
    roleDefinitionId: searchIndexDataContributorRoleDefinitionId
    principalId: backendPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output aiServicesName string = aiServices.name
output aiServicesEndpoint string = aiServices.properties.endpoint
output chatDeploymentName string = chatDeployment.name
output embeddingDeploymentName string = embeddingDeployment.name
output speechServiceName string = speech.name
output speechEndpoint string = speech.properties.endpoint
output speechRegion string = location
output searchServiceName string = search.name
output searchEndpoint string = 'https://${search.name}.search.windows.net'
output searchIndexName string = searchIndexName
output backendOpenAiUserRoleAssignmentId string = hasBackendPrincipal ? backendOpenAiUser.id : ''
output backendSpeechUserRoleAssignmentId string = hasBackendPrincipal ? backendSpeechUser.id : ''
output backendSearchServiceContributorRoleAssignmentId string = hasBackendPrincipal ? backendSearchServiceContributor.id : ''
output backendSearchIndexDataContributorRoleAssignmentId string = hasBackendPrincipal ? backendSearchIndexDataContributor.id : ''
