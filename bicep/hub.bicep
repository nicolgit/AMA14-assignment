targetScope = 'subscription'

@description('Name of the resource group to create and use for the hub lab resources.')
param resourceGroupName string = 'ama-mro-hub'

@description('Azure region for the hub lab resources.')
param location string = 'italynorth'

@description('Common tags applied to all resources.')
param tags object = {
  workload: 'hangarmind'
  environment: 'dev'
  component: 'hub-lab'
}

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
param vmSize string = 'Standard_D4_v5'

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
param osDiskStorageAccountType string = 'Premium_LRS'

@description('Azure Bastion host name.')
param bastionHostName string = 'bas-hub-lab'

@description('Azure Bastion SKU. Developer is the lowest-cost option for a single-user lab; it needs no public IP or AzureBastionSubnet.')
@allowed([
  'Developer'
  'Basic'
  'Standard'
])
param bastionSkuName string = 'Developer'

@description('Azure Bastion public IP name.')
param bastionPublicIpName string = 'pip-bas-hub-lab'

@description('Network security group name for the VM subnet.')
param vmSubnetNsgName string = 'nsg-hub-lab-default'

@description('Network interface name for the virtual machine.')
param networkInterfaceName string = 'nic-hub-lab-upload'

@description('NAT Gateway name for explicit outbound Internet access from the VM subnet.')
param natGatewayName string = 'nat-default'

@description('Public IP name used by the NAT Gateway for outbound Internet access.')
param natGatewayPublicIpName string = 'pip-nat'

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module hubResources './hub-resources.bicep' = {
  name: 'deploy-hub-lab-resources'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [
    hubResourceGroup
  ]
  params: {
    location: location
    tags: tags
    resourceNameSeed: resourceNameSeed
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressPrefix: virtualNetworkAddressPrefix
    defaultSubnetName: defaultSubnetName
    defaultSubnetAddressPrefix: defaultSubnetAddressPrefix
    bastionSubnetName: bastionSubnetName
    bastionSubnetAddressPrefix: bastionSubnetAddressPrefix
    vmName: vmName
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
    osDiskStorageAccountType: osDiskStorageAccountType
    bastionHostName: bastionHostName
    bastionSkuName: bastionSkuName
    bastionPublicIpName: bastionPublicIpName
    vmSubnetNsgName: vmSubnetNsgName
    networkInterfaceName: networkInterfaceName
    natGatewayName: natGatewayName
    natGatewayPublicIpName: natGatewayPublicIpName
  }
}

output resourceGroupName string = hubResourceGroup.name
output resourceGroupId string = hubResourceGroup.id
output virtualNetworkName string = hubResources.outputs.virtualNetworkName
output defaultSubnetName string = hubResources.outputs.defaultSubnetName
output bastionSubnetName string = hubResources.outputs.bastionSubnetName
output vmName string = hubResources.outputs.vmName
output vmPrivateIpAddress string = hubResources.outputs.vmPrivateIpAddress
output bastionHostName string = hubResources.outputs.bastionHostName
output bastionPublicIpAddress string = hubResources.outputs.bastionPublicIpAddress
output natGatewayName string = hubResources.outputs.natGatewayName
output natGatewayPublicIpAddress string = hubResources.outputs.natGatewayPublicIpAddress
