# Carica i dati C-MAPSS su Azure ML: upload blob + data asset + environment.
#
# Solo Azure CLI. Scopre storage/workspace/container dal resource group, carica i
# 3 file FD004 ai path attesi dai data asset, registra i data asset e l'environment
# di training (idempotente: se la versione esiste gia', AML la riusa).
#
# Prerequisiti: az login + estensione ml gia' presenti.

param(
  [string]$RG = 'ama-mro-playground'
)

$base = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$repo = Split-Path $base -Parent

# 1. Scopri storage ML, workspace e container del datastore di default
$acct      = az storage account list -g $RG --query "[?starts_with(name,'stml')].name | [0]" -o tsv
$mlw       = az ml workspace list -g $RG --query "[0].name" -o tsv
$container = az ml datastore show -g $RG -w $mlw -n workspaceblobstore --query container_name -o tsv

# 2. Upload dei 3 file C-MAPSS ai path attesi dai data asset
az storage blob upload --account-name $acct --container-name $container `
  --file "$repo/CMAPPS-data/train_FD004.txt" `
  --name "raw/cmapss/fd004/train/train_FD004.txt" --auth-mode login --overwrite

az storage blob upload --account-name $acct --container-name $container `
  --file "$repo/CMAPPS-data/test_FD004.txt" `
  --name "raw/cmapss/fd004/test/test_FD004.txt" --auth-mode login --overwrite

az storage blob upload --account-name $acct --container-name $container `
  --file "$repo/CMAPPS-data/RUL_FD004.txt" `
  --name "raw/cmapss/fd004/rul/RUL_FD004.txt" --auth-mode login --overwrite

# 3. Registra i data asset
az ml data create -g $RG -w $mlw -f "$repo/azureml/train_fd004.yml"
az ml data create -g $RG -w $mlw -f "$repo/azureml/test_fd004.yml"
az ml data create -g $RG -w $mlw -f "$repo/azureml/rul_fd004.yml"

# 4. Registra l'environment di training (idempotente: se la versione esiste gia,
#    AML la riusa).
az ml environment create -g $RG -w $mlw -f "$repo/azureml/environment/rul-cnnlstm-env.yml"
Write-Host "Dati e environment registrati su $mlw."
