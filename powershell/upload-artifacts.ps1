
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
  # Cartella utente: env var oppure prima cartella sotto Users/
  $authoringUser = $env:AML_NOTEBOOK_USER
  if (-not $authoringUser) {
    $authoringUser = az storage file list --account-name $acct --auth-mode login `
      --enable-file-backup-request-intent --share-name $shareName --path "Users" `
      --query "[0].name" -o tsv
  }

  if (-not $authoringUser) {
    Write-Host "Nessuna cartella utente trovata sotto Users/. Imposta AML_NOTEBOOK_USER e riesegui."
  } else {
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
}
