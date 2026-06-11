
git clone https://github.com/nicolgit/AMA14-assignment
cd .\AMA14-assignment\powershell
git pull

$RG = 'ama-mro-playground'

# Root del repo = cartella padre di powershell/.
# Usa $PSScriptRoot se lo script è eseguito come file, altrimenti la working dir
# (utile quando incolli le righe a mano dopo `cd .../AMA14-assignment/powershell`).
$base = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$repo = Split-Path $base -Parent

# Scopri storage ML, workspace e container del datastore di default
$acct      = az storage account list -g $RG --query "[?starts_with(name,'stml')].name | [0]" -o tsv
$mlw       = az ml workspace list -g $RG --query "[0].name" -o tsv
$container = az ml datastore show -g $RG -w $mlw -n workspaceblobstore --query container_name -o tsv

# 1. Dati: upload ai percorsi esatti attesi dai data asset
az storage blob upload --account-name $acct --auth-mode login -c $container `
  -f "$repo/CMAPPS-data/train_FD004.txt" -n raw/cmapss/fd004/train/train_FD004.txt --overwrite
az storage blob upload --account-name $acct --auth-mode login -c $container `
  -f "$repo/CMAPPS-data/test_FD004.txt"  -n raw/cmapss/fd004/test/test_FD004.txt  --overwrite

# 2. Registra i data asset
az ml data create -g $RG -w $mlw -f "$repo/azureml/train_fd004.yml"
az ml data create -g $RG -w $mlw -f "$repo/azureml/test_fd004.yml"

# 3. (Opzionale) Codice .py nello storage — solo se ti serve davvero a mano.
#    Meglio referenziarlo come `code: ../src` nel YAML del job.
az storage blob upload-batch --account-name $acct --auth-mode login `
  -d "$container/code/src" -s "$repo/src" --pattern "*.py" --overwrite

# 4. Notebook nello storage ML (visibili come file nel workspaceblobstore).
$notebooksPath = "$repo/notebooks"
if (Test-Path $notebooksPath) {
  az storage blob upload-batch --account-name $acct --auth-mode login `
    -d "$container/code/notebooks" -s $notebooksPath --pattern "*.ipynb" --overwrite
} else {
  Write-Host "Cartella notebooks non trovata: $notebooksPath"
}
