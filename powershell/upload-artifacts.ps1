
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
az storage blob upload --account-name $acct --auth-mode login -c $container `
  -f "$repo/CMAPPS-data/RUL_FD004.txt"   -n raw/cmapss/fd004/rul/RUL_FD004.txt    --overwrite
*/

# 2. Registra i data asset
az ml data create -g $RG -w $mlw -f "$repo/azureml/train_fd004.yml"
az ml data create -g $RG -w $mlw -f "$repo/azureml/test_fd004.yml"
az ml data create -g $RG -w $mlw -f "$repo/azureml/rul_fd004.yml"

# Environment (CNN-LSTM)
az ml environment create -f .\azureml\environment\rul-cnnlstm-env.yml -g $RG -w $WS

# 3. Carica nella file share di Authoring tutto il necessario per il training
#    (Azure Files share "code-<guid>"): notebooks, codice src, definizioni azureml
#    (jobs + environment) e i dati C-MAPSS. La struttura del repo viene replicata
#    sotto Users/<user>/AMA14-assignment/ cosi il notebook trova i percorsi attesi.
#    Imposta AML_NOTEBOOK_USER per forzare la cartella utente (es. nicold). Altrimenti
#    viene rilevata automaticamente la prima cartella sotto Users/.

# La share dei notebook ha nome dinamico: code-<guid>
$shareName = az storage share-rm list --resource-group $RG --storage-account $acct `
  --query "[?starts_with(name,'code-')].name | [0]" -o tsv

if (-not $shareName) {
  Write-Host "Share dei notebook (code-*) non trovata nello storage account $acct."
} else {
  # Cartella utente: env var oppure prima cartella sotto Users/.
  # Se Users/ non esiste ancora (compute mai avviata) o e' vuota, si usa il
  # fallback AML_NOTEBOOK_USER (default 'nicold'): upload-batch crea il percorso.
  $authoringUser = $env:AML_NOTEBOOK_USER
  if (-not $authoringUser) {
    # 2>$null evita che ResourceNotFound interrompa lo script.
    $authoringUser = az storage file list --account-name $acct --auth-mode login `
      --enable-file-backup-request-intent --share-name $shareName --path "Users" `
      --query "[0].name" -o tsv 2>$null
  }

  if (-not $authoringUser) {
    $authoringUser = 'nicold'
    Write-Host "Cartella Users/ assente o vuota: uso fallback utente '$authoringUser' (override con AML_NOTEBOOK_USER)."
  }

  $projectRoot = "Users/$authoringUser/AMA14-assignment"
  # Cartelle del repo necessarie al training, caricate ricorsivamente.
  $folders = @('notebooks', 'src', 'azureml', 'CMAPPS-data')

  foreach ($folder in $folders) {
    $localPath = Join-Path $repo $folder
    if (-not (Test-Path $localPath)) {
      Write-Host "Salto $folder (non trovato in $repo)."
      continue
    }
    Write-Host "Carico $folder -> $shareName/$projectRoot/$folder"
    az storage file upload-batch --account-name $acct --auth-mode login `
      --enable-file-backup-request-intent --destination $shareName `
      --destination-path "$projectRoot/$folder" --source $localPath --output none
  }

  Write-Host "Artefatti di training caricati in Authoring (utente $authoringUser)."
}

# 4. Registra l'environment di training (idempotente: se la versione esiste gia,
#    AML la riusa). Il job NON viene sottomesso: il suo YAML e' gia disponibile
#    nella file share (step 3) e si lancia a mano dallo Studio o con:
#      az ml job create -g $RG -w $mlw -f azureml/jobs/train_rul_fd004.yml
az ml environment create -g $RG -w $mlw -f "$repo/azureml/environment/rul-cnnlstm-env.yml"
Write-Host "Environment registrato. Job NON eseguito (YAML disponibile in azureml/jobs/train_rul_fd004.yml)."
