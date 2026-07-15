@description('Azure region for the spoke virtual network.')
param location string = resourceGroup().location

@description('Common tags applied to all resources.')
param tags object = {}

@description('Spoke virtual network name.')
param spokeVirtualNetworkName string = 'hangarmind-spoke-01'

@description('Spoke virtual network address prefix.')
param spokeVirtualNetworkAddressPrefix string = '10.13.0.0/16'

@description('Default subnet name for the spoke.')
param defaultSubnetName string = 'default'

@description('Default subnet address prefix for the spoke.')
param defaultSubnetAddressPrefix string = '10.13.1.0/26'

@description('Private endpoints subnet name for the spoke.')
param privateEndpointsSubnetName string = 'private-endpoints'

@description('Private endpoints subnet address prefix for the spoke.')
param privateEndpointsSubnetAddressPrefix string = '10.13.2.0/26'

@description('Resource ID of the hub virtual network to peer with.')
param hubVirtualNetworkId string

@description('Name of the spoke-to-hub peering.')
param spokeToHubPeeringName string = 'peer-to-hub'

resource spokeVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: spokeVirtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeVirtualNetworkAddressPrefix
      ]
    }
    subnets: [
      {
        name: defaultSubnetName
        properties: {
          addressPrefix: defaultSubnetAddressPrefix
        }
      }
      {
        name: privateEndpointsSubnetName
        properties: {
          addressPrefix: privateEndpointsSubnetAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Spoke -> hub side of the peering. The hub -> spoke side is created separately
// in the hub resource group (see deploy-hub-peering.bicep) because peerings are
// child resources of each virtual network.
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spokeVnet
  name: spokeToHubPeeringName
  properties: {
    remoteVirtualNetwork: {
      id: hubVirtualNetworkId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

output spokeVirtualNetworkId string = spokeVnet.id
output spokeVirtualNetworkName string = spokeVnet.name
output defaultSubnetName string = defaultSubnetName
output privateEndpointsSubnetName string = privateEndpointsSubnetName
output privateEndpointsSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnet.name, privateEndpointsSubnetName)
