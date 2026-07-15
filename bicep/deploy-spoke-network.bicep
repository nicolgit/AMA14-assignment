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

@description('GatewaySubnet address prefix for the Virtual Network Gateway. Must be /27 or larger; name must stay GatewaySubnet.')
param gatewaySubnetAddressPrefix string = '10.13.0.0/27'

@description('DNS Resolver inbound endpoint subnet address prefix. Must be /28 or larger.')
param dnsResolverInboundSubnetAddressPrefix string = '10.13.3.0/28'

@description('DNS Resolver outbound endpoint subnet address prefix. Must be /28 or larger and non-overlapping with inbound.')
param dnsResolverOutboundSubnetAddressPrefix string = '10.13.3.16/28'

@description('Name of the Azure Private DNS Resolver.')
param dnsResolverName string = 'dnsresolver-hangarmind-spoke'

@description('Static private IP address assigned to the DNS Resolver inbound endpoint. Must be within dnsResolverInboundSubnetAddressPrefix (first usable after Azure-reserved .1-.3).')
param dnsResolverInboundIp string = '10.13.3.4'

@description('VPN Gateway Public IP domain name label. This is stable and not date-based, producing an FQDN of the form hangarvpn.<region>.cloudapp.azure.com.')
param vpnGatewayDomainNameLabel string = 'hangarvpn'

@description('Virtual Network Gateway name.')
param vpnGatewayName string = 'vpngw-hangarmind-spoke'

@description('Virtual Network Gateway SKU. VpnGw1 is the cheapest SKU that supports Azure AD P2S authentication and OpenVPN.')
@allowed([
  'VpnGw1'
  'VpnGw2'
  'VpnGw3'
])
param vpnGatewaySku string = 'VpnGw1'

@description('P2S VPN client address pool. Must not overlap with the spoke VNet or other address spaces.')
param vpnClientAddressPool string = '10.14.0.0/16'

@description('Microsoft Entra tenant ID used for Azure AD P2S VPN authentication. Defaults to the subscription tenant.')
param aadTenantId string = subscription().tenantId

@description('Object ID of the user to grant Reader access on the VPN Gateway (allows downloading the VPN client profile). Leave empty to skip the role assignment.')
param vpnGuestUserObjectId string = ''

@description('Resource ID of the hub virtual network to peer with. Leave empty to skip the spoke-to-hub peering.')
param hubVirtualNetworkId string = ''

@description('Name of the spoke-to-hub peering.')
param spokeToHubPeeringName string = 'peer-to-hub'

// Audience for the Azure VPN enterprise application — constant for public Azure cloud.
// See https://learn.microsoft.com/azure/vpn-gateway/openvpn-azure-ad-tenant
var aadAudience = '41b23e61-6c1e-4545-b367-cd054e0ed4b4'

// Built-in Reader role — lets the VPN user view the gateway and download the client profile.
var readerRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')

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
        // Required name for the VPN Gateway subnet; no NSG or route table allowed.
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetAddressPrefix
        }
      }
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
      {
        // Inbound endpoint subnet for the Private DNS Resolver (delegated).
        name: 'dns-resolver-inbound'
        properties: {
          addressPrefix: dnsResolverInboundSubnetAddressPrefix
          delegations: [
            {
              name: 'Microsoft.Network.dnsResolvers'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
      {
        // Outbound endpoint subnet for the Private DNS Resolver (delegated).
        name: 'dns-resolver-outbound'
        properties: {
          addressPrefix: dnsResolverOutboundSubnetAddressPrefix
          delegations: [
            {
              name: 'Microsoft.Network.dnsResolvers'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
    ]
  }
}

// Spoke -> hub side of the peering. Created only when a hub VNet ID is supplied.
// The hub -> spoke side must be created separately in the hub resource group.
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = if (!empty(hubVirtualNetworkId)) {
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

// ---------------------------------------------------------------------------
// Azure Private DNS Resolver — forwards DNS queries from P2S VPN clients to
// Azure's internal resolver, which resolves Private DNS zones linked to the
// spoke VNet (enabling private endpoint name resolution over the VPN).
// ---------------------------------------------------------------------------

resource dnsResolver 'Microsoft.Network/dnsResolvers@2022-07-01' = {
  name: dnsResolverName
  location: location
  tags: tags
  properties: {
    virtualNetwork: {
      id: spokeVnet.id
    }
  }
}

resource dnsResolverInboundEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01' = {
  parent: dnsResolver
  name: 'inbound'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        // Static IP so the address is deterministic and can be referenced as
        // the DNS server in the P2S VPN client configuration below.
        privateIpAllocationMethod: 'Static'
        privateIpAddress: dnsResolverInboundIp
        subnet: {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnet.name, 'dns-resolver-inbound')
        }
      }
    ]
  }
}

resource dnsResolverOutboundEndpoint 'Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01' = {
  parent: dnsResolver
  name: 'outbound'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnet.name, 'dns-resolver-outbound')
    }
  }
}

// ---------------------------------------------------------------------------
// Virtual Network Gateway — P2S VPN with Azure AD authentication.
// Domain name label is stable (not date-based) so the FQDN never changes
// between deployments.
// ---------------------------------------------------------------------------

resource vpnGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${vpnGatewayName}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      // Produces a stable FQDN: <domainNameLabel>.<region>.cloudapp.azure.com
      domainNameLabel: vpnGatewayDomainNameLabel
    }
  }
}

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: vpnGatewayName
  location: location
  tags: tags
  properties: {
    sku: {
      name: vpnGatewaySku
      tier: vpnGatewaySku
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnGatewayGeneration: 'Generation1'
    enableBgp: false
    activeActive: false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vpnGatewayPublicIp.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnet.name, 'GatewaySubnet')
          }
        }
      }
    ]
    vpnClientConfiguration: {
      // Client address pool — must not overlap with any VNet address space.
      vpnClientAddressPool: {
        addressPrefixes: [
          vpnClientAddressPool
        ]
      }
      // OpenVPN protocol is required by the Azure VPN client.
      vpnClientProtocols: [
        'OpenVPN'
      ]
      // Azure AD (Entra ID) is the sole authentication method.
      vpnAuthenticationTypes: [
        'AAD'
      ]
      // environment().authentication.loginEndpoint adapts to sovereign clouds automatically.
      aadTenant: '${environment().authentication.loginEndpoint}${aadTenantId}/'
      aadAudience: aadAudience
      aadIssuer: 'https://sts.windows.net/${aadTenantId}/'
      // VPN clients use the Private DNS Resolver inbound endpoint for name
      // resolution so private endpoint FQDNs resolve correctly over the VPN.
      // vpnClientDnsServers is a valid ARM REST API property on VpnClientConfiguration
      // but is not yet reflected in the Bicep type definitions; suppress the type warning.
      #disable-next-line BCP037
      vpnClientDnsServers: [
        dnsResolverInboundIp
      ]
    }
  }
}

// Grant the specified guest user Reader access on the VPN Gateway so they can
// view the configuration and download the Azure VPN client profile.
resource vpnGuestUserReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(vpnGuestUserObjectId)) {
  name: guid(vpnGateway.id, vpnGuestUserObjectId, readerRoleDefinitionId)
  scope: vpnGateway
  properties: {
    roleDefinitionId: readerRoleDefinitionId
    principalId: vpnGuestUserObjectId
    principalType: 'User'
  }
}

output spokeVirtualNetworkId string = spokeVnet.id
output spokeVirtualNetworkName string = spokeVnet.name
output defaultSubnetName string = defaultSubnetName
output privateEndpointsSubnetName string = privateEndpointsSubnetName
output privateEndpointsSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnet.name, privateEndpointsSubnetName)
output dnsResolverName string = dnsResolver.name
output dnsResolverInboundIpAddress string = dnsResolverInboundIp
output vpnGatewayName string = vpnGateway.name
output vpnGatewayPublicIpFqdn string = vpnGatewayPublicIp.properties.dnsSettings.fqdn
output vpnGatewayPublicIpAddress string = vpnGatewayPublicIp.properties.ipAddress
