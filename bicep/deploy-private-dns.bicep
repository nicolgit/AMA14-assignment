// Private DNS zones for the private endpoints, linked to both the spoke and the
// hub virtual networks so clients in either network resolve the private IPs.
// Zones are global resources; they live in the workload resource group.

@description('Common tags applied to all resources.')
param tags object = {}

@description('Resource ID of the spoke virtual network to link.')
param spokeVirtualNetworkId string

@description('Resource ID of the hub virtual network to link. Leave empty to skip the hub link.')
param hubVirtualNetworkId string = ''

@description('Create a private DNS zone for PostgreSQL. Set false when PostgreSQL is not deployed.')
param enablePostgresZone bool = true

var blobZoneName = 'privatelink.blob.${environment().suffixes.storage}'
var dfsZoneName = 'privatelink.dfs.${environment().suffixes.storage}'
var postgresZoneName = 'privatelink.postgres.database.azure.com'

resource blobZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: blobZoneName
  location: 'global'
  tags: tags
}

resource dfsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: dfsZoneName
  location: 'global'
  tags: tags
}

resource postgresZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (enablePostgresZone) {
  name: postgresZoneName
  location: 'global'
  tags: tags
}

resource blobSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: blobZone
  name: 'link-spoke'
  location: 'global'
  properties: {
    registrationEnabled: false
    resolutionPolicy: 'NxDomainRedirect'
    virtualNetwork: {
      id: spokeVirtualNetworkId
    }
  }
}

resource blobHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(hubVirtualNetworkId)) {
  parent: blobZone
  name: 'link-hub'
  location: 'global'
  properties: {
    registrationEnabled: false
    resolutionPolicy: 'NxDomainRedirect'
    virtualNetwork: {
      id: hubVirtualNetworkId
    }
  }
}

resource dfsSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: dfsZone
  name: 'link-spoke'
  location: 'global'
  properties: {
    registrationEnabled: false
    resolutionPolicy: 'NxDomainRedirect'
    virtualNetwork: {
      id: spokeVirtualNetworkId
    }
  }
}

resource dfsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(hubVirtualNetworkId)) {
  parent: dfsZone
  name: 'link-hub'
  location: 'global'
  properties: {
    registrationEnabled: false
    resolutionPolicy: 'NxDomainRedirect'
    virtualNetwork: {
      id: hubVirtualNetworkId
    }
  }
}

resource postgresSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (enablePostgresZone) {
  parent: postgresZone
  name: 'link-spoke'
  location: 'global'
  properties: {
    registrationEnabled: false
    resolutionPolicy: 'NxDomainRedirect'
    virtualNetwork: {
      id: spokeVirtualNetworkId
    }
  }
}

resource postgresHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (enablePostgresZone && !empty(hubVirtualNetworkId)) {
  parent: postgresZone
  name: 'link-hub'
  location: 'global'
  properties: {
    registrationEnabled: false
    resolutionPolicy: 'NxDomainRedirect'
    virtualNetwork: {
      id: hubVirtualNetworkId
    }
  }
}

output blobPrivateDnsZoneId string = blobZone.id
output dfsPrivateDnsZoneId string = dfsZone.id
output postgresPrivateDnsZoneId string = enablePostgresZone ? postgresZone.id : ''
