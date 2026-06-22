# Lancia la pipeline Azure ML train -> evaluate (serverless: nessun compute da
# pre-creare). La pipeline esegue i due step in sequenza e passa gli artefatti del
# train (model.pt + scaler.pkl) all'evaluate. Per il solo training usare invece
# azureml/jobs/train_rul_fd004.yml.
#
# Prerequisiti: dati e environment gia' registrati (vedi populate-train-data.ps1).

param(
  [string]$RG = 'ama-mro-playground'
)

$base = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$repo = Split-Path $base -Parent

$mlw = az ml workspace list -g $RG --query "[0].name" -o tsv

az ml job create -f "$repo/azureml/jobs/pipeline_rul_fd004.yml" -g $RG -w $mlw
Write-Host "Pipeline train -> evaluate lanciata. Controlla lo stato con - az ml job list -g $RG -w $mlw -o table"
