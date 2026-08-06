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
  [string]$DeploymentName = ''
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

function Test-EngineeringSearchOutputs {
  param(
    [object]$Outputs
  )

  return [bool](
    (Get-DeploymentOutputValue -Outputs $Outputs -Name 'engineeringSearchServiceName') -and
    (Get-DeploymentOutputValue -Outputs $Outputs -Name 'engineeringSearchEndpoint') -and
    (Get-DeploymentOutputValue -Outputs $Outputs -Name 'dataLakeAccountName') -and
    (Get-DeploymentOutputValue -Outputs $Outputs -Name 'dataLakeAccountId') -and
    (Get-DeploymentOutputValue -Outputs $Outputs -Name 'engineeringAiServicesEndpoint') -and
    (Get-DeploymentOutputValue -Outputs $Outputs -Name 'engineeringAiServicesId') -and
    (Get-DeploymentOutputValue -Outputs $Outputs -Name 'engineeringAiServicesName')
  )
}

function Get-SubscriptionDeploymentOutputs {
  param(
    [string]$Name = ''
  )

  if ($Name) {
    Write-Host "`nLoading deployment outputs from subscription deployment '$Name'..." -ForegroundColor Cyan
    $outputsJson = az deployment sub show -n $Name --query properties.outputs -o json 2>$null
    if ($LASTEXITCODE -eq 0 -and $outputsJson) {
      $outputs = $outputsJson | ConvertFrom-Json
      if ($outputs -and (Test-EngineeringSearchOutputs -Outputs $outputs)) {
        return @{ Name = $Name; Outputs = $outputs }
      }
    }

    Write-Warning "Subscription deployment '$Name' was not found or does not contain the Engineering Search outputs. Searching for the latest timestamped subscription deployment..."
  }
  else {
    Write-Host "`nSearching for the latest 'deploy-yyMMdd-HHmm' subscription deployment..." -ForegroundColor Cyan
  }

  $deploymentsJson = az deployment sub list --query "[].{name:name,state:properties.provisioningState,timestamp:properties.timestamp}" -o json
  if ($LASTEXITCODE -ne 0 -or -not $deploymentsJson) {
    throw 'Could not list subscription deployments. Run az login and verify that the selected subscription is correct.'
  }

  $deployment = $deploymentsJson | ConvertFrom-Json |
    Where-Object { $_.name -match '^deploy-(\d{6}|\d{8})-\d{4}$' } |
    Sort-Object { [DateTimeOffset]$_.timestamp } -Descending |
    Select-Object -First 1
  if (-not $deployment) {
    throw "No subscription deployment matching 'deploy-yyMMdd-HHmm' or 'deploy-yyyyMMdd-HHmm' was found."
  }

  Write-Host "  Using latest subscription deployment '$($deployment.name)' (state: $($deployment.state))." -ForegroundColor Green
  $outputsJson = az deployment sub show -n $deployment.name --query properties.outputs -o json 2>$null
  if ($LASTEXITCODE -eq 0 -and $outputsJson) {
    $outputs = $outputsJson | ConvertFrom-Json
    if ($outputs -and (Test-EngineeringSearchOutputs -Outputs $outputs)) {
      return @{ Name = $deployment.name; Outputs = $outputs }
    }
  }

  throw "Latest subscription deployment '$($deployment.name)' (state: $($deployment.state)) does not contain the Engineering Search outputs."
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
    --query "properties.privateEndpointConnections[?properties.privateLinkServiceConnectionState.status=='Pending'].name" `
    -o tsv

  if (-not $connections) {
    Write-Host "  No pending AI Services private endpoint connections found." -ForegroundColor DarkGray
    return
  }

  foreach ($connectionName in ($connections -split "`r?`n" | Where-Object { $_ })) {
    $connectionId = az cognitiveservices account show `
      --name $AccountName `
      --resource-group $ResourceGroupName `
      --query "properties.privateEndpointConnections[?name=='$connectionName'].id | [0]" `
      -o tsv

    if (-not $connectionId) {
      throw "Could not resolve private endpoint connection ID for '$connectionName'."
    }

    az resource update `
      --ids $connectionId `
      --api-version 2024-10-01 `
      --set properties.privateLinkServiceConnectionState.status=Approved `
            properties.privateLinkServiceConnectionState.description='Approved for Azure AI Search embedding generation' `
            properties.privateLinkServiceConnectionState.actionsRequired=None `
      --only-show-errors | Out-Null

    if ($LASTEXITCODE -ne 0) {
      throw "Failed to approve AI Services connection: $connectionName"
    }

    Write-Host "  Approved AI Services connection: $connectionName" -ForegroundColor Green
  }
}

$deploymentResult = Get-SubscriptionDeploymentOutputs -Name $DeploymentName
$outputs = $deploymentResult.Outputs

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

$searchAdminKey = az search admin-key show --resource-group $RG --service-name $searchServiceName --query primaryKey -o tsv 2>$null
if ($LASTEXITCODE -eq 0 -and $searchAdminKey) {
  $configureParams.SearchAdminKey = $searchAdminKey
}

Write-Host "`nConfiguring Azure AI Search index '$($configureParams.IndexName)' on '$searchServiceName'..." -ForegroundColor Cyan
& $configureSearchIndex @configureParams