@description('Azure region for the hub lab resources.')
param location string = resourceGroup().location

@description('Common tags applied to all resources.')
param tags object = {}

@description('Deterministic seed used to build resource names.')
param resourceNameSeed string = 'hub-lab'

@description('Hub virtual network name.')
param virtualNetworkName string = 'hub-lab-net'

@description('Hub virtual network address prefix.')
param virtualNetworkAddressPrefix string = '10.12.0.0/16'

@description('Default subnet name for the lab VM.')
param defaultSubnetName string = 'default'

@description('Default subnet address prefix for the lab VM.')
param defaultSubnetAddressPrefix string = '10.12.1.0/24'

@description('Azure Bastion subnet name. Must be AzureBastionSubnet.')
param bastionSubnetName string = 'AzureBastionSubnet'

@description('Azure Bastion subnet address prefix. Azure Bastion requires /26 or larger.')
param bastionSubnetAddressPrefix string = '10.12.2.0/24'

@description('Virtual machine name.')
param vmName string = 'vm-hub-lab-upload'

@description('Virtual machine size. Standard_D4s_v5 provides 4 vCPU and 16 GiB RAM in France Central.')
param vmSize string = 'Standard_D4s_v5'

@description('Local administrator username for the virtual machine.')
param adminUsername string = 'azureuser'

// PoC shortcut: this VM has no public IP and is reachable only through Bastion.
// For production, pass this value at deployment time instead of keeping a default.
@secure()
@description('Local administrator password for the virtual machine. Pass this at deployment time.')
param adminPassword string = 'pass@word123!'

@description('Windows 11 image publisher.')
param imagePublisher string = 'MicrosoftWindowsDesktop'

@description('Windows 11 image offer.')
param imageOffer string = 'windows-11'

@description('Windows 11 image SKU.')
param imageSku string = 'win11-24h2-pro'

@description('Windows 11 image version.')
param imageVersion string = 'latest'

@description('OS disk type for the virtual machine.')
@allowed([
  'Premium_LRS'
  'StandardSSD_LRS'
  'Standard_LRS'
])
param osDiskStorageAccountType string = 'StandardSSD_LRS'

@description('Azure Bastion host name.')
param bastionHostName string = 'bas-hub-lab'

@description('Azure Bastion SKU. Basic is sufficient for a single-user lab scenario.')
@allowed([
  'Basic'
  'Standard'
])
param bastionSkuName string = 'Basic'

@description('Azure Bastion public IP name.')
param bastionPublicIpName string = 'pip-bas-hub-lab'

@description('Network security group name for the VM subnet.')
param vmSubnetNsgName string = 'nsg-hub-lab-default'

@description('Network interface name for the virtual machine.')
param networkInterfaceName string = 'nic-hub-lab-upload'

@description('NAT Gateway name for explicit outbound Internet access from the VM subnet.')
param natGatewayName string = 'nat-hub-lab-default'

@description('Public IP name used by the NAT Gateway for outbound Internet access.')
param natGatewayPublicIpName string = 'pip-nat-hub-lab-default'

var nameSeedSafe = toLower(replace(resourceNameSeed, '-', ''))
var osDiskName = toLower(take('osdisk-${nameSeedSafe}', 80))

resource vmSubnetNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: vmSubnetNsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource natGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: natGatewayPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-05-01' = {
  name: natGatewayName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: natGatewayPublicIp.id
      }
    ]
  }
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
    subnets: [
      {
        name: defaultSubnetName
        properties: {
          addressPrefix: defaultSubnetAddressPrefix
          networkSecurityGroup: {
            id: vmSubnetNsg.id
          }
          natGateway: {
            id: natGateway.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: bastionSubnetAddressPrefix
        }
      }
    ]
  }
}

resource vmNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: networkInterfaceName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnet.name, defaultSubnetName)
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: take(vmName, 15)
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        name: osDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskStorageAccountType
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: bastionPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: bastionHostName
  location: location
  tags: tags
  sku: {
    name: bastionSkuName
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnet.name, bastionSubnetName)
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

output virtualNetworkName string = hubVnet.name
output defaultSubnetName string = defaultSubnetName
output bastionSubnetName string = bastionSubnetName
output vmName string = vm.name
output vmPrivateIpAddress string = vmNic.properties.ipConfigurations[0].properties.privateIPAddress
output bastionHostName string = bastionHost.name
output bastionPublicIpAddress string = bastionPublicIp.properties.ipAddress
output natGatewayName string = natGateway.name
output natGatewayPublicIpAddress string = natGatewayPublicIp.properties.ipAddress
