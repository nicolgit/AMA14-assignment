# Carica i dati manutentivi sul Data Lake ADLS Gen2 del PoC.
#
# Solo Azure CLI. Scopre lo storage lake dal resource group e carica:
#   - data-sample-maintenance-doc/ -> engineering-docs/sample-docs
#
# Usa Entra ID/RBAC con --auth-mode login, come populate-train-data.ps1.
# Prerequisiti: az login gia' effettuato; utente con Storage Blob Data Contributor
# sul Data Lake; connettivita' di rete verso lo Storage Account.

param(
  [string]$RG = 'ama-mro-playground'
)

$ErrorActionPreference = 'Stop'

$base = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$repo = Split-Path $base -Parent
$maintenanceDocsDir = Join-Path $repo 'data-sample-maintenance-doc'

if (-not (Test-Path $maintenanceDocsDir)) {
  throw "Cartella documenti manutentivi non trovata: $maintenanceDocsDir"
}

# 1. Scopri il Data Lake creato dal modulo bicep/deploy-datalake.bicep
$acct = az storage account list -g $RG --query "[?starts_with(name,'lake')].name | [0]" -o tsv
if (-not $acct) {
  throw "Nessun Data Lake storage account trovato in $RG."
}

Write-Host "Data Lake storage account: $acct"

# 2. Verifica accesso data-plane con Entra ID prima di caricare
az storage container list --account-name $acct --auth-mode login --query "[].name" -o table

# 3. Carica documentazione manutentiva per AI03/RAG
az storage blob upload-batch `
  --account-name $acct `
  --destination engineering-docs `
  --destination-path sample-docs `
  --source $maintenanceDocsDir `
  --auth-mode login `
  --overwrite

Write-Host "Dati manutentivi caricati su $acct."