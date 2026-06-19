
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

# Upload dei 3 file C-MAPSS ai path attesi dai data asset
az storage blob upload --account-name $acct --container-name $container `
  --file "$repo/CMAPPS-data/train_FD004.txt" `
  --name "raw/cmapss/fd004/train/train_FD004.txt" --auth-mode login --overwrite

az storage blob upload --account-name $acct --container-name $container `
  --file "$repo/CMAPPS-data/test_FD004.txt" `
  --name "raw/cmapss/fd004/test/test_FD004.txt" --auth-mode login --overwrite

az storage blob upload --account-name $acct --container-name $container `
  --file "$repo/CMAPPS-data/RUL_FD004.txt" `
  --name "raw/cmapss/fd004/rul/RUL_FD004.txt" --auth-mode login --overwrite

# 2. Registra i data asset
az ml data create -g $RG -w $mlw -f "$repo/azureml/train_fd004.yml"
az ml data create -g $RG -w $mlw -f "$repo/azureml/test_fd004.yml"
az ml data create -g $RG -w $mlw -f "$repo/azureml/rul_fd004.yml"

# 4. Registra l'environment di training (idempotente: se la versione esiste gia,
#    AML la riusa). 
az ml environment create -g $RG -w $mlw -f "$repo/azureml/environment/rul-cnnlstm-env.yml"
Write-Host "Environment registrato. Job NON eseguito (YAML disponibile in azureml/jobs/train_rul_fd004.yml)."

# 4. Lancia la pipeline train -> evaluate (serverless: nessun compute da pre-creare).
#    La pipeline esegue i due step in sequenza e passa gli artefatti del train
#    (model.pt + scaler.pkl) all'evaluate. Per il solo training usare invece
#    azureml/jobs/train_rul_fd004.yml.
az ml job create -f "$repo/azureml/jobs/pipeline_rul_fd004.yml" -g $RG -w $mlw
Write-Host "Pipeline train -> evaluate lanciata. Controlla lo stato con - az ml job list -g $RG -w $mlw -o table"

