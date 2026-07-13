<#
Orchestratore: prepara dati e lancia la pipeline ML del PoC.

git clone https://github.com/nicolgit/AMA14-assignment
cd .\AMA14-assignment\powershell
git pull
.\upload.ps1 

Esegue in sequenza:
  1. populate-sql.ps1         -> crea e popola le tabelle su PostgreSQL
  2. populate-engine-data.ps1 -> crea e popola engine_data da CMAPPS-data/test_FD004.txt
  3. populate-train-data.ps1  -> carica i dati C-MAPSS + environment su Azure ML
  4. populate-maintenance-data.ps1 -> carica documenti e dati manutentivi sul Data Lake
  5. start-ml-pipeline.ps1    -> lancia la pipeline train -> evaluate

Prerequisiti: az login gia' effettuato; estensioni ml e rdbms-connect.
#>

param(
  [string]$RG = 'ama-mro-playground'
)

$base = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

& "$base/populate-sql.ps1" -RG $RG
& "$base/populate-engine-data.ps1" -RG $RG
& "$base/populate-train-data.ps1" -RG $RG
& "$base/populate-maintenance-data.ps1" -RG $RG
& "$base/start-ml-pipeline.ps1" -RG $RG
