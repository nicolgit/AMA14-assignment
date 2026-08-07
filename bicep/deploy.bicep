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

@description('Deterministic seed used to build resource names across modules. Includes MMdd from deploy time; pin an explicit value to keep re-deploy idempotent across days.')
param resourceNameSeed string = 'amamrodeve${utcNow('MMdd')}'

@description('Microsoft Entra object ID of the user running the deployment. This principal will receive Storage Blob Data Contributor on the Data Lake account.')
param deployerObjectId string = '6e94d310-1194-469a-af8e-bd502dcf2782' // get from `az ad signed-in-user show --query id -o tsv`

@description('Microsoft Entra UPN of the deployer. Used to grant the deployer PostgreSQL Entra admin.')
param deployerPrincipalName string = 'nicold_microsoft.com#EXT#@MngEnvMCAP361336.onmicrosoft.com' // get from `az ad signed-in-user show --query userPrincipalName -o tsv`

@description('Spoke virtual network name.')
param spokeVirtualNetworkName string = 'hangarmind-spoke-01'

@description('Spoke virtual network address prefix.')
param spokeVirtualNetworkAddressPrefix string = '10.13.0.0/16'

@description('Engineering Copilot chat model deployment name.')
param engineeringChatDeploymentName string = 'gpt-5-6-sol'

@description('Engineering Copilot chat model name. Override if a newer chat model is available in the selected region.')
param engineeringChatModelName string = 'gpt-5.6-sol'

@description('Engineering Copilot chat model version. Must be available in the selected region.')
param engineeringChatModelVersion string = '2026-07-09'

@description('Engineering Copilot chat deployment SKU. GPT-5.6 Sol in France Central supports GlobalStandard and DataZoneStandard.')
@allowed([
  'GlobalStandard'
  'DataZoneStandard'
  'Standard'
])
param engineeringChatDeploymentSku string = 'DataZoneStandard'

@description('Engineering Copilot embedding model deployment name.')
param engineeringEmbeddingDeploymentName string = 'text-embedding-3-large'

@description('Engineering Copilot embedding model name.')
param engineeringEmbeddingModelName string = 'text-embedding-3-large'

@description('Engineering Copilot embedding model version. Must be available in the selected region.')
param engineeringEmbeddingModelVersion string = '1'

@description('Azure AI Search SKU for the Engineering Copilot RAG index.')
@allowed([
  'free'
  'basic'
  'standard'
  'standard2'
  'standard3'
])
param engineeringSearchSku string = 'standard'

@description('Common tags applied to all resources.')
param tags object = {
  workload: 'hangarmind'
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
    resourceNameSeed: resourceNameSeed
    tags: tags
    publicNetworkAccess: 'Disabled'
  }
}

// 3. RBAC on current user for the Data Lake storage account
module currentUser 'current-user.bicep' = {
  name: 'current-user'
  scope: rg
  params: {
    deployerObjectId: deployerObjectId
    storageAccountName: datalake.outputs.storageAccountName
  }
}

// 4. Container Registry associated with the ML workspace
module acr 'deploy-acr.bicep' = {
  name: 'deploy-acr'
  scope: rg
  params: {
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
  }
}

// 5. ML + Monitoring platform
module mlplatform 'deploy-ml.bicep' = {
  name: 'deploy-ml'
  scope: rg
  params: {
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
    containerRegistryId: acr.outputs.containerRegistryId
  }
}

// 6. RBAC on current user for the AML workspace storage account
module currentUserMlStorage 'current-user.bicep' = {
  name: 'current-user-ml-storage'
  scope: rg
  params: {
    deployerObjectId: deployerObjectId
    storageAccountName: mlplatform.outputs.mlWorkspaceStorageAccountName
    grantFilePrivilegedContributor: true
  }
}

// 7. Managed identity used by the backend to reach PostgreSQL passwordless (Entra auth)
module backendIdentity 'deploy-identity.bicep' = {
  name: 'deploy-identity'
  scope: rg
  params: {
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
  }
}

// 8. Azure AI Foundry/OpenAI + Azure AI Search for Engineering Copilot RAG
module engineeringAi 'deploy-ai.bicep' = {
  name: 'deploy-engineering-ai'
  scope: rg
  params: {
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
    backendPrincipalId: backendIdentity.outputs.principalId
    deployerPrincipalId: deployerObjectId
    chatDeploymentName: engineeringChatDeploymentName
    chatModelName: engineeringChatModelName
    chatModelVersion: engineeringChatModelVersion
    chatDeploymentSku: engineeringChatDeploymentSku
    embeddingDeploymentName: engineeringEmbeddingDeploymentName
    embeddingModelName: engineeringEmbeddingModelName
    embeddingModelVersion: engineeringEmbeddingModelVersion
    searchSku: engineeringSearchSku
    // Wire up the Data Lake so the Search managed identity receives Storage Blob Data Reader
    // and a Shared Private Link is created to allow private indexing.
    dataLakeStorageAccountName: datalake.outputs.storageAccountName
    dataLakeStorageAccountId: datalake.outputs.storageAccountId
    disablePublicNetworkAccess: true
  }
}

// 9. PostgreSQL Flexible Server (small PoC SKU, Entra-only auth)
module postgres 'deploy-postgres.bicep' = {
  name: 'deploy-postgres'
  scope: rg
  params: {
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
    authMode: 'EntraOnly'
    entraAdminObjectId: backendIdentity.outputs.principalId
    entraAdminPrincipalName: backendIdentity.outputs.identityName
    additionalEntraAdminObjectId: deployerObjectId
    additionalEntraAdminPrincipalName: deployerPrincipalName
  }
}

// 10. Container Apps environment hosting the backend API and the frontend SPA
module containerApps 'deploy-containerapps.bicep' = {
  name: 'deploy-containerapps'
  scope: rg
  params: {
    location: location
    resourceNameSeed: resourceNameSeed
    tags: tags
    logAnalyticsWorkspaceName: mlplatform.outputs.logAnalyticsWorkspaceName
    infrastructureSubnetId: spokeNetwork.outputs.containerAppsSubnetId
    containerRegistryName: acr.outputs.containerRegistryName
    containerRegistryLoginServer: acr.outputs.containerRegistryLoginServer
    containerRegistryPullIdentityId: backendIdentity.outputs.containerRegistryPullIdentityResourceId
    containerRegistryPullPrincipalId: backendIdentity.outputs.containerRegistryPullIdentityPrincipalId
    backendUserAssignedIdentityId: backendIdentity.outputs.identityResourceId
    backendUserAssignedIdentityClientId: backendIdentity.outputs.clientId
    backendPrincipalId: backendIdentity.outputs.principalId
    applicationInsightsConnectionString: mlplatform.outputs.applicationInsightsConnectionString
    postgresFqdn: postgres.outputs.postgresFqdn
    postgresDatabaseName: postgres.outputs.postgresDatabaseName
    postgresUser: backendIdentity.outputs.identityName
    dataLakeStorageAccountName: datalake.outputs.storageAccountName
    dataLakeBlobEndpoint: datalake.outputs.primaryBlobEndpoint
    azureOpenAiEndpoint: engineeringAi.outputs.aiServicesEndpoint
    azureOpenAiChatDeployment: engineeringAi.outputs.chatDeploymentName
    azureOpenAiEmbeddingDeployment: engineeringAi.outputs.embeddingDeploymentName
    azureSearchEndpoint: engineeringAi.outputs.searchEndpoint
    azureSearchIndexName: engineeringAi.outputs.searchIndexName
    azureSpeechEndpoint: engineeringAi.outputs.speechEndpoint
    azureSpeechResourceId: engineeringAi.outputs.speechServiceId
    azureSpeechRegion: engineeringAi.outputs.speechRegion
  }
}

// 11. Hangarmind spoke virtual network with Private DNS Resolver and P2S VPN Gateway
module spokeNetwork 'deploy-spoke-network.bicep' = {
  name: 'deploy-spoke-network'
  scope: rg
  params: {
    location: location
    tags: tags
    spokeVirtualNetworkName: spokeVirtualNetworkName
    spokeVirtualNetworkAddressPrefix: spokeVirtualNetworkAddressPrefix
    // Grant the deployer Reader access on the VPN Gateway so they can download
    // the Azure VPN client profile from the portal and connect via P2S VPN.
    vpnGuestUserObjectId: deployerObjectId
  }
}

// 12. Private DNS zones (blob, dfs, postgres) linked to the spoke
module privateDns 'deploy-private-dns.bicep' = {
  name: 'deploy-private-dns'
  scope: rg
  params: {
    tags: tags
    spokeVirtualNetworkId: spokeNetwork.outputs.spokeVirtualNetworkId
    enablePostgresZone: true
  }
}

// 13. Private endpoints (Data Lake storage + PostgreSQL) with static private IPs on the spoke
module privateEndpoints 'deploy-private-endpoints.bicep' = {
  name: 'deploy-private-endpoints'
  scope: rg
  params: {
    location: location
    tags: tags
    privateEndpointsSubnetId: spokeNetwork.outputs.privateEndpointsSubnetId
    dataLakeStorageAccountId: datalake.outputs.storageAccountId
    postgresServerId: postgres.outputs.postgresServerId
    blobPrivateDnsZoneId: privateDns.outputs.blobPrivateDnsZoneId
    dfsPrivateDnsZoneId: privateDns.outputs.dfsPrivateDnsZoneId
    postgresPrivateDnsZoneId: privateDns.outputs.postgresPrivateDnsZoneId
  }
}

// 14. Private endpoints + DNS zones for the AI stack (AI Services, Speech, Search)
module aiPrivateEndpoints 'deploy-ai-private-endpoints.bicep' = {
  name: 'deploy-ai-private-endpoints'
  scope: rg
  params: {
    location: location
    tags: tags
    privateEndpointsSubnetId: spokeNetwork.outputs.privateEndpointsSubnetId
    spokeVirtualNetworkId: spokeNetwork.outputs.spokeVirtualNetworkId
    aiServicesId: engineeringAi.outputs.aiServicesId
    speechServiceId: engineeringAi.outputs.speechServiceId
    searchServiceId: engineeringAi.outputs.searchServiceId
  }
}

output resourceGroupId string = rg.id
output spokeVirtualNetworkName string = spokeNetwork.outputs.spokeVirtualNetworkName
output spokeVirtualNetworkId string = spokeNetwork.outputs.spokeVirtualNetworkId
output vpnGatewayName string = spokeNetwork.outputs.vpnGatewayName
output vpnGatewayPublicIpFqdn string = spokeNetwork.outputs.vpnGatewayPublicIpFqdn
output vpnGatewayPublicIpAddress string = spokeNetwork.outputs.vpnGatewayPublicIpAddress
output dnsResolverName string = spokeNetwork.outputs.dnsResolverName
output dnsResolverInboundIpAddress string = spokeNetwork.outputs.dnsResolverInboundIpAddress
output dataLakeBlobPrivateIpAddress string = privateEndpoints.outputs.dataLakeBlobPrivateIpAddress
output dataLakeDfsPrivateIpAddress string = privateEndpoints.outputs.dataLakeDfsPrivateIpAddress
output postgresPrivateIpAddress string = privateEndpoints.outputs.postgresPrivateIpAddress
output aiServicesPrivateIpAddress string = aiPrivateEndpoints.outputs.aiServicesPrivateIpAddress
output speechPrivateIpAddress string = aiPrivateEndpoints.outputs.speechPrivateIpAddress
output searchPrivateIpAddress string = aiPrivateEndpoints.outputs.searchPrivateIpAddress
output dataLakeAccountName string = datalake.outputs.storageAccountName
output dataLakeAccountId string = datalake.outputs.storageAccountId
output dataLakePrimaryDfsEndpoint string = datalake.outputs.primaryDfsEndpoint
output dataLakeContainerNames array = datalake.outputs.containerNames
output currentUserBlobDataContributorRoleAssignmentId string = currentUser.outputs.storageBlobDataContributorRoleAssignmentId
output mlWorkspaceStorageBlobDataContributorRoleAssignmentId string = currentUserMlStorage.outputs.storageBlobDataContributorRoleAssignmentId
output mlWorkspaceName string = mlplatform.outputs.mlWorkspaceName
output mlOnlineEndpointName string = mlplatform.outputs.mlOnlineEndpointName
output keyVaultName string = mlplatform.outputs.keyVaultName
output applicationInsightsName string = mlplatform.outputs.applicationInsightsName
output logAnalyticsWorkspaceName string = mlplatform.outputs.logAnalyticsWorkspaceName
output mlWorkspaceStorageAccountName string = mlplatform.outputs.mlWorkspaceStorageAccountName
output containerRegistryName string = acr.outputs.containerRegistryName
output containerRegistryLoginServer string = acr.outputs.containerRegistryLoginServer
output postgresServerName string = postgres.outputs.postgresServerName
output postgresFqdn string = postgres.outputs.postgresFqdn
output postgresDatabaseName string = postgres.outputs.postgresDatabaseName
output engineeringAiServicesName string = engineeringAi.outputs.aiServicesName
output engineeringAiServicesEndpoint string = engineeringAi.outputs.aiServicesEndpoint
output engineeringAiServicesId string = engineeringAi.outputs.aiServicesId
output engineeringAiChatDeploymentName string = engineeringAi.outputs.chatDeploymentName
output engineeringAiEmbeddingDeploymentName string = engineeringAi.outputs.embeddingDeploymentName
output engineeringSpeechServiceName string = engineeringAi.outputs.speechServiceName
output engineeringSpeechEndpoint string = engineeringAi.outputs.speechEndpoint
output engineeringSpeechRegion string = engineeringAi.outputs.speechRegion
output engineeringSearchServiceName string = engineeringAi.outputs.searchServiceName
output engineeringSearchEndpoint string = engineeringAi.outputs.searchEndpoint
output engineeringSearchIndexName string = engineeringAi.outputs.searchIndexName
output engineeringSearchManagedIdentityPrincipalId string = engineeringAi.outputs.searchManagedIdentityPrincipalId
output containerAppsEnvironmentName string = containerApps.outputs.containerAppsEnvironmentName
output backendApiAppName string = containerApps.outputs.backendAppName
output backendApiFqdn string = containerApps.outputs.backendFqdn
output frontendSpaAppName string = containerApps.outputs.frontendAppName
output frontendSpaFqdn string = containerApps.outputs.frontendFqdn
