@description('Azure region for the private endpoints. Must match the subnet region.')
param location string = resourceGroup().location

@description('Common tags applied to all resources.')
param tags object = {}

@description('Resource ID of the subnet that hosts the private endpoints (private-endpoints subnet on the spoke).')
param privateEndpointsSubnetId string

@description('Resource ID of the Data Lake (ADLS Gen2) storage account to expose privately.')
param dataLakeStorageAccountId string

@description('Static private IP for the Data Lake blob private endpoint.')
param dataLakeBlobPrivateIpAddress string = '10.13.2.4'

@description('Static private IP for the Data Lake dfs private endpoint.')
param dataLakeDfsPrivateIpAddress string = '10.13.2.5'

@description('Resource ID of the PostgreSQL Flexible Server to expose privately. Leave empty to skip.')
param postgresServerId string = ''

@description('Static private IP for the PostgreSQL private endpoint.')
param postgresPrivateIpAddress string = '10.13.2.6'

@description('Resource ID of the blob private DNS zone. Leave empty to skip the DNS zone group.')
param blobPrivateDnsZoneId string = ''

@description('Resource ID of the dfs private DNS zone. Leave empty to skip the DNS zone group.')
param dfsPrivateDnsZoneId string = ''

@description('Resource ID of the PostgreSQL private DNS zone. Leave empty to skip the DNS zone group.')
param postgresPrivateDnsZoneId string = ''

@description('Base name used to build private endpoint resource names.')
param namePrefix string = 'pe-hangarmind'

var dataLakeStorageAccountName = last(split(dataLakeStorageAccountId, '/'))

// Data Lake (ADLS Gen2) exposes two sub-resources: blob and dfs. Each needs its
// own private endpoint with a dedicated static IP from the private-endpoints subnet.
resource dataLakeBlobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${namePrefix}-${dataLakeStorageAccountName}-blob'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    ipConfigurations: [
      {
        name: 'ipconfig-blob'
        properties: {
          groupId: 'blob'
          memberName: 'blob'
          privateIPAddress: dataLakeBlobPrivateIpAddress
        }
      }
    ]
    privateLinkServiceConnections: [
      {
        name: 'plsc-${dataLakeStorageAccountName}-blob'
        properties: {
          privateLinkServiceId: dataLakeStorageAccountId
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource dataLakeBlobDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!empty(blobPrivateDnsZoneId)) {
  parent: dataLakeBlobPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob'
        properties: {
          privateDnsZoneId: blobPrivateDnsZoneId
        }
      }
    ]
  }
}

resource dataLakeDfsPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${namePrefix}-${dataLakeStorageAccountName}-dfs'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    ipConfigurations: [
      {
        name: 'ipconfig-dfs'
        properties: {
          groupId: 'dfs'
          memberName: 'dfs'
          privateIPAddress: dataLakeDfsPrivateIpAddress
        }
      }
    ]
    privateLinkServiceConnections: [
      {
        name: 'plsc-${dataLakeStorageAccountName}-dfs'
        properties: {
          privateLinkServiceId: dataLakeStorageAccountId
          groupIds: [
            'dfs'
          ]
        }
      }
    ]
  }
}

resource dataLakeDfsDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!empty(dfsPrivateDnsZoneId)) {
  parent: dataLakeDfsPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'dfs'
        properties: {
          privateDnsZoneId: dfsPrivateDnsZoneId
        }
      }
    ]
  }
}

// PostgreSQL Flexible Server (public-access mode) exposed via a private endpoint.
resource postgresPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = if (!empty(postgresServerId)) {
  name: '${namePrefix}-${last(split(postgresServerId, '/'))}-postgres'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    ipConfigurations: [
      {
        name: 'ipconfig-postgres'
        properties: {
          groupId: 'postgresqlServer'
          memberName: 'postgresqlServer'
          privateIPAddress: postgresPrivateIpAddress
        }
      }
    ]
    privateLinkServiceConnections: [
      {
        name: 'plsc-postgres'
        properties: {
          privateLinkServiceId: postgresServerId
          groupIds: [
            'postgresqlServer'
          ]
        }
      }
    ]
  }
}

resource postgresDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!empty(postgresServerId) && !empty(postgresPrivateDnsZoneId)) {
  parent: postgresPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'postgres'
        properties: {
          privateDnsZoneId: postgresPrivateDnsZoneId
        }
      }
    ]
  }
}

output dataLakeBlobPrivateEndpointId string = dataLakeBlobPrivateEndpoint.id
output dataLakeBlobPrivateIpAddress string = dataLakeBlobPrivateIpAddress
output dataLakeDfsPrivateEndpointId string = dataLakeDfsPrivateEndpoint.id
output dataLakeDfsPrivateIpAddress string = dataLakeDfsPrivateIpAddress
output postgresPrivateEndpointId string = !empty(postgresServerId) ? postgresPrivateEndpoint.id : ''
output postgresPrivateIpAddress string = !empty(postgresServerId) ? postgresPrivateIpAddress : ''
