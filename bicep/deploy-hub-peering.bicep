// Creates the hub -> spoke side of a VNet peering. Deployed into the hub
// resource group because the peering is a child of the existing hub VNet.

@description('Name of the existing hub virtual network.')
param hubVirtualNetworkName string = 'hub-lab-net'

@description('Resource ID of the spoke virtual network to peer with.')
param spokeVirtualNetworkId string

@description('Name of the hub-to-spoke peering.')
param hubToSpokePeeringName string = 'peer-to-hangarmind-spoke-01'

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: hubVirtualNetworkName
}

resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: hubVnet
  name: hubToSpokePeeringName
  properties: {
    remoteVirtualNetwork: {
      id: spokeVirtualNetworkId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}
