# Carica i CSV di data-sample/ come tabelle su PostgreSQL Flexible Server.
#
# Approccio "furbo" (analogo a upload.ps1): solo Azure CLI, nessun psql.
#   1. scopre server + database dal resource group
#   2. genera DDL + INSERT direttamente dai CSV (sempre in sync con i file)
#   3. esegue lo script con `az postgres flexible-server execute` usando un token
#      Entra come password (connessione passwordless)
#
# Prerequisiti: az login gia' effettuato (l'utente e' gia' admin Entra del server,
# assegnato a deployment time); estensione rdbms-connect (si auto-installa).

param(
  [string]$RG = 'ama-mro-playground'
)

$DB = 'mro'

$base = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$repo = Split-Path $base -Parent
$sampleDir = Join-Path $repo 'data-sample'

# 1. Scopri il server PostgreSQL nel resource group
$server = az postgres flexible-server list -g $RG --query "[?starts_with(name,'pg')].name | [0]" -o tsv
if (-not $server) { throw "Nessun PostgreSQL Flexible Server trovato in $RG." }
Write-Host "Server: $server  /  database: $DB"

# 2. Genera lo script SQL (DDL + dati) dai CSV
function ConvertTo-SqlText($v) {
  if ($null -eq $v -or "$v" -eq '') { return 'NULL' }
  return "'" + ("$v" -replace "'", "''") + "'"
}
function ConvertTo-SqlInt($v) {
  if ($null -eq $v -or "$v" -eq '') { return 'NULL' }
  return [string][int]$v
}

$sb = New-Object System.Text.StringBuilder

# --- DDL ---
[void]$sb.AppendLine(@'
CREATE TABLE IF NOT EXISTS location (
  location_code text PRIMARY KEY,
  location_name text NOT NULL,
  place         text NOT NULL
);

CREATE TABLE IF NOT EXISTS status (
  status_code text PRIMARY KEY,
  status_name text NOT NULL,
  description text
);

CREATE TABLE IF NOT EXISTS aircraft (
  aircraft_id         text PRIMARY KEY,
  model               text,
  engine_count        int,
  engine_ids          text,
  operator            text,
  total_flight_cycles int,
  status              text REFERENCES status(status_code),
  msn                 text,
  in_service_date     date,
  total_flight_hours  int,
  base_location       text REFERENCES location(location_code)
);

-- ricarica pulita (idempotente)
TRUNCATE TABLE aircraft;
TRUNCATE TABLE location CASCADE;
TRUNCATE TABLE status   CASCADE;
'@)

# --- location ---
$loc = Import-Csv (Join-Path $sampleDir 'location.csv')
$vals = $loc | ForEach-Object {
  "($(ConvertTo-SqlText $_.location_code), $(ConvertTo-SqlText $_.location_name), $(ConvertTo-SqlText $_.place))"
}
[void]$sb.AppendLine("INSERT INTO location (location_code, location_name, place) VALUES")
[void]$sb.AppendLine(($vals -join ",`n") + ";")

# --- status ---
$st = Import-Csv (Join-Path $sampleDir 'status.csv')
$vals = $st | ForEach-Object {
  "($(ConvertTo-SqlText $_.status_code), $(ConvertTo-SqlText $_.status_name), $(ConvertTo-SqlText $_.description))"
}
[void]$sb.AppendLine("INSERT INTO status (status_code, status_name, description) VALUES")
[void]$sb.AppendLine(($vals -join ",`n") + ";")

# --- aircraft ---
$ac = Import-Csv (Join-Path $sampleDir 'aircraft.csv')
$vals = $ac | ForEach-Object {
  '(' + (@(
    ConvertTo-SqlText $_.aircraft_id
    ConvertTo-SqlText $_.model
    ConvertTo-SqlInt  $_.engine_count
    ConvertTo-SqlText $_.engine_ids
    ConvertTo-SqlText $_.operator
    ConvertTo-SqlInt  $_.total_flight_cycles
    ConvertTo-SqlText $_.status
    ConvertTo-SqlText $_.msn
    ConvertTo-SqlText $_.in_service_date
    ConvertTo-SqlInt  $_.total_flight_hours
    ConvertTo-SqlText $_.base_location
  ) -join ', ') + ')'
}
[void]$sb.AppendLine("INSERT INTO aircraft (aircraft_id, model, engine_count, engine_ids, operator, total_flight_cycles, status, msn, in_service_date, total_flight_hours, base_location) VALUES")
[void]$sb.AppendLine(($vals -join ",`n") + ";")

$sqlFile = Join-Path ([System.IO.Path]::GetTempPath()) 'load-data-sample.generated.sql'
Set-Content -Path $sqlFile -Value $sb.ToString() -Encoding utf8
Write-Host "Script SQL generato: $sqlFile  (location=$($loc.Count), status=$($st.Count), aircraft=$($ac.Count))"

# 3. Esegui lo script usando un token Entra come password (passwordless)
$upn   = az ad signed-in-user show --query userPrincipalName -o tsv
$token = az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv
az postgres flexible-server execute `
  --name $server `
  --admin-user $upn `
  --admin-password $token `
  --database-name $DB `
  --file-path $sqlFile `
  --output table

Write-Host "Tabelle create e popolate su $server/$DB."
