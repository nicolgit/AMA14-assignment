// Private endpoints and private DNS zones for the Engineering Copilot AI stack:
// AI Services (OpenAI), AI Speech and AI Search. Zones are linked to both the
// spoke and hub virtual networks so clients in either resolve the private IPs.

@description('Azure region for the private endpoints. Must match the subnet region.')
param location string = resourceGroup().location

@description('Common tags applied to all resources.')
param tags object = {}

@description('Resource ID of the subnet that hosts the private endpoints (private-endpoints subnet on the spoke).')
param privateEndpointsSubnetId string

@description('Resource ID of the spoke virtual network to link to the DNS zones.')
param spokeVirtualNetworkId string

@description('Resource ID of the hub virtual network to link to the DNS zones. Leave empty to skip the hub link.')
param hubVirtualNetworkId string = ''

@description('Resource ID of the AI Services (Cognitive Services) account.')
param aiServicesId string

@description('Resource ID of the AI Speech (Cognitive Services) account.')
param speechServiceId string

@description('Resource ID of the AI Search service.')
param searchServiceId string

@description('Static private IP for the AI Services private endpoint.')
param aiServicesPrivateIpAddress string = '10.13.2.7'

@description('Static private IP for the AI Services private endpoint secondary member (required for kind AIServices).')
param aiServicesSecondaryPrivateIpAddress string = '10.13.2.10'

@description('Static private IP for the AI Services private endpoint third member (required for kind AIServices).')
param aiServicesThirdPrivateIpAddress string = '10.13.2.11'

@description('Static private IP for the AI Speech private endpoint.')
param speechPrivateIpAddress string = '10.13.2.8'

@description('Static private IP for the AI Search private endpoint.')
param searchPrivateIpAddress string = '10.13.2.9'

@description('Base name used to build private endpoint resource names.')
param namePrefix string = 'pe-hangarmind'

var cognitiveServicesZoneName = 'privatelink.cognitiveservices.azure.com'
var openAiZoneName = 'privatelink.openai.azure.com'
var aiServicesZoneName = 'privatelink.services.ai.azure.com'
var searchZoneName = 'privatelink.search.windows.net'

var aiServicesName = last(split(aiServicesId, '/'))
var speechName = last(split(speechServiceId, '/'))
var searchName = last(split(searchServiceId, '/'))

// -- Private DNS zones --------------------------------------------------------

resource cognitiveServicesZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: cognitiveServicesZoneName
  location: 'global'
  tags: tags
}

resource openAiZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: openAiZoneName
  location: 'global'
  tags: tags
}

resource aiServicesZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: aiServicesZoneName
  location: 'global'
  tags: tags
}

resource searchZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: searchZoneName
  location: 'global'
  tags: tags
}

// -- VNet links (spoke + hub) for each zone ----------------------------------

resource cognitiveServicesSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: cognitiveServicesZone
  name: 'link-spoke'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: spokeVirtualNetworkId
    }
  }
}

resource cognitiveServicesHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(hubVirtualNetworkId)) {
  parent: cognitiveServicesZone
  name: 'link-hub'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVirtualNetworkId
    }
  }
}

resource openAiSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: openAiZone
  name: 'link-spoke'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: spokeVirtualNetworkId
    }
  }
}

resource openAiHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(hubVirtualNetworkId)) {
  parent: openAiZone
  name: 'link-hub'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVirtualNetworkId
    }
  }
}

resource aiServicesSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: aiServicesZone
  name: 'link-spoke'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: spokeVirtualNetworkId
    }
  }
}

resource aiServicesHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(hubVirtualNetworkId)) {
  parent: aiServicesZone
  name: 'link-hub'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVirtualNetworkId
    }
  }
}

resource searchSpokeLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: searchZone
  name: 'link-spoke'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: spokeVirtualNetworkId
    }
  }
}

resource searchHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(hubVirtualNetworkId)) {
  parent: searchZone
  name: 'link-hub'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVirtualNetworkId
    }
  }
}

// -- Private endpoints --------------------------------------------------------

// AI Services (kind AIServices) registers into the cognitiveservices, openai and
// services.ai zones so every SDK surface resolves privately.
resource aiServicesPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${namePrefix}-${aiServicesName}-account'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    ipConfigurations: [
      {
        name: 'ipconfig-account'
        properties: {
          groupId: 'account'
          memberName: 'default'
          privateIPAddress: aiServicesPrivateIpAddress
        }
      }
      {
        name: 'ipconfig-account-secondary'
        properties: {
          groupId: 'account'
          memberName: 'secondary'
          privateIPAddress: aiServicesSecondaryPrivateIpAddress
        }
      }
      {
        name: 'ipconfig-account-third'
        properties: {
          groupId: 'account'
          memberName: 'third'
          privateIPAddress: aiServicesThirdPrivateIpAddress
        }
      }
    ]
    privateLinkServiceConnections: [
      {
        name: 'plsc-${aiServicesName}'
        properties: {
          privateLinkServiceId: aiServicesId
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

resource aiServicesDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: aiServicesPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cognitiveservices'
        properties: {
          privateDnsZoneId: cognitiveServicesZone.id
        }
      }
      {
        name: 'openai'
        properties: {
          privateDnsZoneId: openAiZone.id
        }
      }
      {
        name: 'servicesai'
        properties: {
          privateDnsZoneId: aiServicesZone.id
        }
      }
    ]
  }
}

resource speechPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${namePrefix}-${speechName}-account'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    ipConfigurations: [
      {
        name: 'ipconfig-account'
        properties: {
          groupId: 'account'
          memberName: 'default'
          privateIPAddress: speechPrivateIpAddress
        }
      }
    ]
    privateLinkServiceConnections: [
      {
        name: 'plsc-${speechName}'
        properties: {
          privateLinkServiceId: speechServiceId
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

resource speechDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: speechPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cognitiveservices'
        properties: {
          privateDnsZoneId: cognitiveServicesZone.id
        }
      }
    ]
  }
}

resource searchPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${namePrefix}-${searchName}-searchService'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    ipConfigurations: [
      {
        name: 'ipconfig-searchService'
        properties: {
          groupId: 'searchService'
          memberName: 'searchService'
          privateIPAddress: searchPrivateIpAddress
        }
      }
    ]
    privateLinkServiceConnections: [
      {
        name: 'plsc-${searchName}'
        properties: {
          privateLinkServiceId: searchServiceId
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
  }
}

resource searchDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: searchPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'search'
        properties: {
          privateDnsZoneId: searchZone.id
        }
      }
    ]
  }
}

output aiServicesPrivateEndpointId string = aiServicesPrivateEndpoint.id
output aiServicesPrivateIpAddress string = aiServicesPrivateIpAddress
output aiServicesSecondaryPrivateIpAddress string = aiServicesSecondaryPrivateIpAddress
output aiServicesThirdPrivateIpAddress string = aiServicesThirdPrivateIpAddress
output speechPrivateEndpointId string = speechPrivateEndpoint.id
output speechPrivateIpAddress string = speechPrivateIpAddress
output searchPrivateEndpointId string = searchPrivateEndpoint.id
output searchPrivateIpAddress string = searchPrivateIpAddress
