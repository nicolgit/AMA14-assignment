<#
Configura la parte Engineering Copilot RAG dopo il deployment e l'upload dati.

Esegue in sequenza:
  1. legge gli output del deployment subscription
  2. approva le Shared Private Link pending di Azure AI Search verso Storage
  3. approva le Shared Private Link pending di Azure AI Search verso AI Services/OpenAI
  4. configura data source, indice, skillset e indexer di Azure AI Search

Prerequisiti: az login gia' effettuato; client connesso alla VPN P2S quando Search e Storage hanno public network access disabilitato.
#>

param(
  [string]$RG = 'ama-mro-playground',
  [string]$DeploymentName = 'hangarmind-dev'
)

$base = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

function Get-DeploymentOutputValue {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Outputs,
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $property = $Outputs.PSObject.Properties[$Name]
  if ($null -eq $property -or $null -eq $property.Value) {
    return $null
  }

  return $property.Value.value
}

function Approve-StoragePendingPrivateEndpointConnections {
  param(
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName
  )

  Write-Host "`nApproving pending Search shared private link connection(s) on storage account '$StorageAccountName'..." -ForegroundColor Cyan

  $connections = az storage account show `
    --name $StorageAccountName `
    --query "privateEndpointConnections[?privateLinkServiceConnectionState.status=='Pending'].name" `
    -o tsv

  if (-not $connections) {
    Write-Host "  No pending storage private endpoint connections found." -ForegroundColor DarkGray
    return
  }

  foreach ($connectionName in ($connections -split "`r?`n" | Where-Object { $_ })) {
    az storage account private-endpoint-connection approve `
      --account-name $StorageAccountName `
      --name $connectionName `
      --description 'Approved for Azure AI Search indexing' `
      --only-show-errors | Out-Null

    Write-Host "  Approved storage connection: $connectionName" -ForegroundColor Green
  }
}

function Approve-CognitiveServicesPendingPrivateEndpointConnections {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$AccountName
  )

  Write-Host "`nApproving pending Search shared private link connection(s) on AI Services account '$AccountName'..." -ForegroundColor Cyan

  $connections = az cognitiveservices account show `
    --name $AccountName `
    --resource-group $ResourceGroupName `
    --query "properties.privateEndpointConnections[?privateLinkServiceConnectionState.status=='Pending'].name" `
    -o tsv

  if (-not $connections) {
    Write-Host "  No pending AI Services private endpoint connections found." -ForegroundColor DarkGray
    return
  }

  foreach ($connectionName in ($connections -split "`r?`n" | Where-Object { $_ })) {
    az cognitiveservices account private-endpoint-connection approve `
      --resource-group $ResourceGroupName `
      --account-name $AccountName `
      --name $connectionName `
      --description 'Approved for Azure AI Search embedding generation' `
      --only-show-errors | Out-Null

    Write-Host "  Approved AI Services connection: $connectionName" -ForegroundColor Green
  }
}

Write-Host "`nLoading deployment outputs from subscription deployment '$DeploymentName'..." -ForegroundColor Cyan
$outputs = az deployment sub show -n $DeploymentName --query properties.outputs -o json | ConvertFrom-Json

$searchServiceName = Get-DeploymentOutputValue -Outputs $outputs -Name 'engineeringSearchServiceName'
$searchEndpoint = Get-DeploymentOutputValue -Outputs $outputs -Name 'engineeringSearchEndpoint'
$storageAccountName = Get-DeploymentOutputValue -Outputs $outputs -Name 'dataLakeAccountName'
$storageAccountId = Get-DeploymentOutputValue -Outputs $outputs -Name 'dataLakeAccountId'
$openAiEndpoint = Get-DeploymentOutputValue -Outputs $outputs -Name 'engineeringAiServicesEndpoint'
$openAiResourceId = Get-DeploymentOutputValue -Outputs $outputs -Name 'engineeringAiServicesId'
$openAiAccountName = Get-DeploymentOutputValue -Outputs $outputs -Name 'engineeringAiServicesName'
$embeddingDeploymentName = Get-DeploymentOutputValue -Outputs $outputs -Name 'engineeringAiEmbeddingDeploymentName'
$searchIndexName = Get-DeploymentOutputValue -Outputs $outputs -Name 'engineeringSearchIndexName'

if (-not $searchServiceName -or -not $searchEndpoint -or -not $storageAccountName -or -not $storageAccountId -or -not $openAiEndpoint -or -not $openAiResourceId -or -not $openAiAccountName) {
  Write-Warning 'Engineering Copilot Search outputs were not found. Skipping Search shared private link approval and index configuration.'
  return
}

Approve-StoragePendingPrivateEndpointConnections -StorageAccountName $storageAccountName
Approve-CognitiveServicesPendingPrivateEndpointConnections -ResourceGroupName $RG -AccountName $openAiAccountName

$configureSearchIndex = Join-Path $base 'configure-search-index.ps1'
$configureParams = @{
  SearchServiceName = $searchServiceName
  SearchEndpoint = $searchEndpoint
  StorageAccountName = $storageAccountName
  StorageAccountId = $storageAccountId
  OpenAiEndpoint = $openAiEndpoint
  OpenAiResourceId = $openAiResourceId
}

if ($embeddingDeploymentName) {
  $configureParams.EmbeddingDeploymentName = $embeddingDeploymentName
}
if ($searchIndexName) {
  $configureParams.IndexName = $searchIndexName
}

Write-Host "`nConfiguring Azure AI Search index '$($configureParams.IndexName)' on '$searchServiceName'..." -ForegroundColor Cyan
& $configureSearchIndex @configureParams