@description('Azure region.')
param location string = resourceGroup().location

@description('Deterministic seed used to build resource names across modules.')
param resourceNameSeed string

@description('Common tags.')
param tags object = {}

@description('Name of an existing Log Analytics workspace (same resource group) used for container logs.')
param logAnalyticsWorkspaceName string

@description('Container image for the backend API.')
param backendImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

@description('Container image for the frontend SPA (static web app served by a web server).')
param frontendImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

@description('Port the backend API container listens on.')
param backendTargetPort int = 8080

@description('Port the frontend SPA container listens on.')
param frontendTargetPort int = 80

@description('CPU cores per container (PoC default).')
param cpu string = '0.25'

@description('Memory per container (PoC default).')
param memory string = '0.5Gi'

@description('Minimum replicas (0 = scale to zero to save cost in a PoC).')
param minReplicas int = 0

@description('Maximum replicas.')
param maxReplicas int = 2

@description('Resource ID of the user-assigned managed identity used by the backend to reach PostgreSQL.')
param backendUserAssignedIdentityId string = ''

@description('Client ID of the backend managed identity (used by the app to acquire an Entra token).')
param backendUserAssignedIdentityClientId string = ''

@description('PostgreSQL server FQDN the backend connects to.')
param postgresFqdn string = ''

@description('PostgreSQL database name the backend connects to.')
param postgresDatabaseName string = ''

@description('PostgreSQL Entra username for the backend (the managed identity name).')
param postgresUser string = ''

@description('Application Insights connection string. Shared by all telemetry-capable services so traces land in one instance.')
param applicationInsightsConnectionString string = ''

@description('Azure AI Foundry/OpenAI endpoint used by the backend API.')
param azureOpenAiEndpoint string = ''

@description('Azure OpenAI chat model deployment name used by the backend API.')
param azureOpenAiChatDeployment string = ''

@description('Azure OpenAI embedding model deployment name used by ingestion/RAG.')
param azureOpenAiEmbeddingDeployment string = ''

@description('Azure AI Search endpoint used by the backend API.')
param azureSearchEndpoint string = ''

@description('Default Azure AI Search index name used by the backend API.')
param azureSearchIndexName string = ''

@description('Azure AI Speech endpoint used by the backend API.')
param azureSpeechEndpoint string = ''

@description('Azure AI Speech region used by the backend API.')
param azureSpeechRegion string = ''

var nameSeedSafe = toLower(replace(resourceNameSeed, '-', ''))
var environmentName = toLower(take('cae-${nameSeedSafe}', 32))
var backendAppName = toLower(take('api-${nameSeedSafe}', 32))
var frontendAppName = toLower(take('web-${nameSeedSafe}', 32))

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: law.properties.customerId
        sharedKey: law.listKeys().primarySharedKey
      }
    }
  }
}

var hasBackendIdentity = !empty(backendUserAssignedIdentityId)
var hasAppInsights = !empty(applicationInsightsConnectionString)
var hasAzureOpenAi = !empty(azureOpenAiEndpoint)
var hasAzureSearch = !empty(azureSearchEndpoint)
var hasAzureSpeech = !empty(azureSpeechEndpoint)

var appInsightsEnv = hasAppInsights ? [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: applicationInsightsConnectionString
  }
] : []

var backendEnv = concat([
  {
    name: 'POSTGRES_HOST'
    value: postgresFqdn
  }
  {
    name: 'POSTGRES_DATABASE'
    value: postgresDatabaseName
  }
  {
    name: 'POSTGRES_USER'
    value: postgresUser
  }
], hasBackendIdentity ? [
  {
    name: 'AZURE_CLIENT_ID'
    value: backendUserAssignedIdentityClientId
  }
] : [], appInsightsEnv, hasAzureOpenAi ? [
  {
    name: 'AZURE_OPENAI_ENDPOINT'
    value: azureOpenAiEndpoint
  }
  {
    name: 'AZURE_OPENAI_CHAT_DEPLOYMENT'
    value: azureOpenAiChatDeployment
  }
  {
    name: 'AZURE_OPENAI_EMBEDDING_DEPLOYMENT'
    value: azureOpenAiEmbeddingDeployment
  }
] : [], hasAzureSearch ? [
  {
    name: 'AZURE_SEARCH_ENDPOINT'
    value: azureSearchEndpoint
  }
  {
    name: 'AZURE_SEARCH_INDEX_NAME'
    value: azureSearchIndexName
  }
] : [], hasAzureSpeech ? [
  {
    name: 'AZURE_SPEECH_ENDPOINT'
    value: azureSpeechEndpoint
  }
  {
    name: 'AZURE_SPEECH_REGION'
    value: azureSpeechRegion
  }
] : [])

// Backend API container app (external ingress so the SPA can call it from the browser).
resource backend 'Microsoft.App/containerApps@2024-03-01' = {
  name: backendAppName
  location: location
  tags: tags
  identity: hasBackendIdentity ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${backendUserAssignedIdentityId}': {}
    }
  } : {
    type: 'None'
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        external: true
        targetPort: backendTargetPort
        transport: 'auto'
        allowInsecure: false
      }
    }
    template: {
      containers: [
        {
          name: 'api'
          image: backendImage
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: backendEnv
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

// Frontend SPA container app (public entry point).
resource frontend 'Microsoft.App/containerApps@2024-03-01' = {
  name: frontendAppName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        external: true
        targetPort: frontendTargetPort
        transport: 'auto'
        allowInsecure: false
      }
    }
    template: {
      containers: [
        {
          name: 'web'
          image: frontendImage
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          // The SPA reaches the backend via its public FQDN.
          env: concat([
            {
              name: 'BACKEND_API_URL'
              value: 'https://${backend.properties.configuration.ingress.fqdn}'
            }
          ], appInsightsEnv)
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output containerAppsEnvironmentName string = environment.name
output containerAppsEnvironmentId string = environment.id
output backendAppName string = backend.name
output backendFqdn string = backend.properties.configuration.ingress.fqdn
output frontendAppName string = frontend.name
output frontendFqdn string = frontend.properties.configuration.ingress.fqdn
