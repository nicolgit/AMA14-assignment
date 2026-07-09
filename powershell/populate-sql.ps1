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

$DB = 'hangarmind'

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
function ConvertTo-SqlFloat($v) {
  if ($null -eq $v -or "$v" -eq '') { return 'NULL' }
  return [string]([double]$v).ToString([System.Globalization.CultureInfo]::InvariantCulture)
}
function Add-InsertStatement {
  param(
    [System.Text.StringBuilder]$Builder,
    [string]$TableName,
    [string]$ColumnList,
    [object[]]$Rows
  )

  if ($null -eq $Rows -or $Rows.Count -eq 0) {
    return
  }

  [void]$Builder.AppendLine("INSERT INTO $TableName ($ColumnList) VALUES")
  [void]$Builder.AppendLine(($Rows -join ",`n") + ";")
}

$sb = New-Object System.Text.StringBuilder

# --- DDL ---
[void]$sb.AppendLine(@'
CREATE TABLE IF NOT EXISTS location (
  location_code text PRIMARY KEY,
  location_name text NOT NULL,
  place         text NOT NULL,
  latitude      double precision,
  longitude     double precision
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

CREATE TABLE IF NOT EXISTS engine (
  engineid              text PRIMARY KEY,
  manifacturer          text,
  engine_serial_number  text,
  position_on_iarcraft  text,
  installation_date     date
);

CREATE TABLE IF NOT EXISTS prediction (
  engine_id     int PRIMARY KEY,
  predicted_rul real
);

CREATE TABLE IF NOT EXISTS evaluation (
  name  text PRIMARY KEY,
  value real
);

CREATE TABLE IF NOT EXISTS spare_part (
  part_number text PRIMARY KEY,
  name        text NOT NULL
);

CREATE TABLE IF NOT EXISTS spare_part_location (
  part_number text REFERENCES spare_part(part_number),
  location    text REFERENCES location(location_code),
  on_hand     int,
  reserved    int,
  min_stock   int,
  PRIMARY KEY (part_number, location)
);

CREATE TABLE IF NOT EXISTS location_distance (
  location_1    text REFERENCES location(location_code),
  location_2    text REFERENCES location(location_code),
  distance      real,
  transfer_time int,
  transfer_cost real,
  PRIMARY KEY (location_1, location_2)
);

-- ricarica pulita (idempotente)
TRUNCATE TABLE aircraft;
TRUNCATE TABLE engine;
TRUNCATE TABLE spare_part_location;
TRUNCATE TABLE location_distance;
TRUNCATE TABLE spare_part;
TRUNCATE TABLE location CASCADE;
TRUNCATE TABLE status   CASCADE;
TRUNCATE TABLE prediction;
TRUNCATE TABLE evaluation;
'@)

# --- location ---
$loc = Import-Csv (Join-Path $sampleDir 'location.csv')
$vals = $loc | ForEach-Object {
  "($(ConvertTo-SqlText $_.location_code), $(ConvertTo-SqlText $_.location_name), $(ConvertTo-SqlText $_.place), $(ConvertTo-SqlFloat $_.latitude), $(ConvertTo-SqlFloat $_.longitude))"
}
Add-InsertStatement -Builder $sb -TableName 'location' -ColumnList 'location_code, location_name, place, latitude, longitude' -Rows $vals

# --- status ---
$st = Import-Csv (Join-Path $sampleDir 'status.csv')
$vals = $st | ForEach-Object {
  "($(ConvertTo-SqlText $_.status_code), $(ConvertTo-SqlText $_.status_name), $(ConvertTo-SqlText $_.description))"
}
Add-InsertStatement -Builder $sb -TableName 'status' -ColumnList 'status_code, status_name, description' -Rows $vals

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
Add-InsertStatement -Builder $sb -TableName 'aircraft' -ColumnList 'aircraft_id, model, engine_count, engine_ids, operator, total_flight_cycles, status, msn, in_service_date, total_flight_hours, base_location' -Rows $vals

# --- engine ---
$eng = Import-Csv (Join-Path $sampleDir 'engine.csv')
$vals = $eng | ForEach-Object {
  '(' + (@(
    ConvertTo-SqlText $_.engineid
    ConvertTo-SqlText $_.manifacturer
    ConvertTo-SqlText $_.engine_serial_number
    ConvertTo-SqlText $_.position_on_iarcraft
    ConvertTo-SqlText $_.installation_date
  ) -join ', ') + ')'
}
Add-InsertStatement -Builder $sb -TableName 'engine' -ColumnList 'engineid, manifacturer, engine_serial_number, position_on_iarcraft, installation_date' -Rows $vals

# --- spare_part ---
$sp = Import-Csv (Join-Path $sampleDir 'spare-part.csv')
$vals = $sp | ForEach-Object {
  "($(ConvertTo-SqlText $_.part_number), $(ConvertTo-SqlText $_.name))"
}
Add-InsertStatement -Builder $sb -TableName 'spare_part' -ColumnList 'part_number, name' -Rows $vals

# --- spare_part_location ---
$spl = Import-Csv (Join-Path $sampleDir 'spare-part-location.csv')
$vals = $spl | ForEach-Object {
  '(' + (@(
    ConvertTo-SqlText $_.part_number
    ConvertTo-SqlText $_.location
    ConvertTo-SqlInt  $_.on_hand
    ConvertTo-SqlInt  $_.reserved
    ConvertTo-SqlInt  $_.min_stock
  ) -join ', ') + ')'
}
Add-InsertStatement -Builder $sb -TableName 'spare_part_location' -ColumnList 'part_number, location, on_hand, reserved, min_stock' -Rows $vals

# --- location_distance ---
$ld = Import-Csv (Join-Path $sampleDir 'location-distance.csv')
$vals = $ld | ForEach-Object {
  '(' + (@(
    ConvertTo-SqlText  $_.location_1
    ConvertTo-SqlText  $_.location_2
    ConvertTo-SqlFloat $_.distance
    ConvertTo-SqlInt   $_.transfer_time
    ConvertTo-SqlFloat $_.transfer_cost
  ) -join ', ') + ')'
}
Add-InsertStatement -Builder $sb -TableName 'location_distance' -ColumnList 'location_1, location_2, distance, transfer_time, transfer_cost' -Rows $vals

# --- prediction ---
$predFile = Join-Path $repo 'ml-outputs/predictions.csv'
$pred = Import-Csv $predFile
$vals = $pred | ForEach-Object {
  "($(ConvertTo-SqlInt $_.engine_id), $(ConvertTo-SqlFloat $_.predicted_rul))"
}
Add-InsertStatement -Builder $sb -TableName 'prediction' -ColumnList 'engine_id, predicted_rul' -Rows $vals

# --- evaluation ---
$evalFile = Join-Path $repo 'ml-outputs/evaluation.json'
$eval = Get-Content $evalFile -Raw | ConvertFrom-Json
$vals = $eval.PSObject.Properties | ForEach-Object {
  "($(ConvertTo-SqlText $_.Name), $(ConvertTo-SqlFloat $_.Value))"
}
Add-InsertStatement -Builder $sb -TableName 'evaluation' -ColumnList 'name, value' -Rows $vals

$sqlFile = Join-Path ([System.IO.Path]::GetTempPath()) 'load-data-sample.generated.sql'
Set-Content -Path $sqlFile -Value $sb.ToString() -Encoding utf8
Write-Host "Script SQL generato: $sqlFile  (location=$($loc.Count), status=$($st.Count), aircraft=$($ac.Count), engine=$($eng.Count), spare_part=$($sp.Count), spare_part_location=$($spl.Count), location_distance=$($ld.Count), prediction=$($pred.Count), evaluation=$($eval.PSObject.Properties.Count))"

# 3. Esegui lo script usando un token Entra come password (passwordless)
# `execute` vive nell'estensione rdbms-connect: installala se manca.
az extension show --name rdbms-connect -o none 2>$null
if ($LASTEXITCODE -ne 0) { az extension add --name rdbms-connect --only-show-errors }

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
