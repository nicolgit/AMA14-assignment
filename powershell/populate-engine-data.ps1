# Crea e popola la tabella engine_data su PostgreSQL Flexible Server
# partendo da CMAPPS-data/test_FD004.txt.
#
# Mapping colonne preso da CMAPPS-data/readme.md:
#  1  unit number
#  2  time, in cycles
#  3  operational setting 1
#  4  operational setting 2
#  5  operational setting 3
#  6-26 sensor measurement 1..21
#
# Approccio: solo Azure CLI + estensione rdbms-connect (niente psql locale).
# Prerequisiti: az login gia effettuato e permessi admin Entra sul server PostgreSQL.

param(
  [string]$RG = 'ama-mro-playground',
  [string]$DB = 'hangarmind',
  [string]$TableName = 'engine_data',
  [int]$BatchSize = 1000
)

$ErrorActionPreference = 'Stop'

$base = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$repo = Split-Path $base -Parent
$testFile = Join-Path $repo 'CMAPPS-data/test_FD004.txt'

if (-not (Test-Path $testFile)) {
  throw "File non trovato: $testFile"
}

if ($BatchSize -lt 1) {
  throw 'BatchSize deve essere >= 1.'
}

# 1) Scopri server PostgreSQL nel resource group
$server = az postgres flexible-server list -g $RG --query "[?starts_with(name,'pg')].name | [0]" -o tsv
if (-not $server) { throw "Nessun PostgreSQL Flexible Server trovato in $RG." }
Write-Host "Server: $server  /  database: $DB  /  tabella: $TableName"

function ConvertTo-SqlInt([string]$v) {
  if ([string]::IsNullOrWhiteSpace($v)) { return 'NULL' }
  return [string][int]$v
}

function ConvertTo-SqlFloat([string]$v) {
  if ([string]::IsNullOrWhiteSpace($v)) { return 'NULL' }
  return [string]([double]$v).ToString([System.Globalization.CultureInfo]::InvariantCulture)
}

# 2) Genera script SQL (DDL + load dati)
$sb = New-Object System.Text.StringBuilder

[void]$sb.AppendLine("CREATE TABLE IF NOT EXISTS $TableName (")
[void]$sb.AppendLine('  unit_number            int  NOT NULL,')
[void]$sb.AppendLine('  time_in_cycles         int  NOT NULL,')
[void]$sb.AppendLine('  operational_setting_1  real NOT NULL,')
[void]$sb.AppendLine('  operational_setting_2  real NOT NULL,')
[void]$sb.AppendLine('  operational_setting_3  real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_1   real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_2   real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_3   real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_4   real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_5   real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_6   real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_7   real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_8   real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_9   real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_10  real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_11  real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_12  real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_13  real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_14  real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_15  real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_16  real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_17  real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_18  real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_19  real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_20  real NOT NULL,')
[void]$sb.AppendLine('  sensor_measurement_21  real NOT NULL,')
[void]$sb.AppendLine('  PRIMARY KEY (unit_number, time_in_cycles)')
[void]$sb.AppendLine(');')
[void]$sb.AppendLine()
[void]$sb.AppendLine("TRUNCATE TABLE $TableName;")

$lines = Get-Content -Path $testFile
$totalRows = 0
$batchRows = New-Object System.Collections.Generic.List[string]

$insertHeader = @"
INSERT INTO $TableName (
  unit_number, time_in_cycles,
  operational_setting_1, operational_setting_2, operational_setting_3,
  sensor_measurement_1, sensor_measurement_2, sensor_measurement_3, sensor_measurement_4, sensor_measurement_5,
  sensor_measurement_6, sensor_measurement_7, sensor_measurement_8, sensor_measurement_9, sensor_measurement_10,
  sensor_measurement_11, sensor_measurement_12, sensor_measurement_13, sensor_measurement_14, sensor_measurement_15,
  sensor_measurement_16, sensor_measurement_17, sensor_measurement_18, sensor_measurement_19, sensor_measurement_20,
  sensor_measurement_21
) VALUES
"@

foreach ($line in $lines) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }

  # Split robusto su spazi multipli/tabs (il file ha spazi variabili e trailing spaces)
  $parts = ($line.Trim() -split '\s+')
  if ($parts.Count -ne 26) {
    throw "Riga non valida: attese 26 colonne, trovate $($parts.Count). Riga: $line"
  }

  $rowValues = @(
    ConvertTo-SqlInt   $parts[0]
    ConvertTo-SqlInt   $parts[1]
    ConvertTo-SqlFloat $parts[2]
    ConvertTo-SqlFloat $parts[3]
    ConvertTo-SqlFloat $parts[4]
    ConvertTo-SqlFloat $parts[5]
    ConvertTo-SqlFloat $parts[6]
    ConvertTo-SqlFloat $parts[7]
    ConvertTo-SqlFloat $parts[8]
    ConvertTo-SqlFloat $parts[9]
    ConvertTo-SqlFloat $parts[10]
    ConvertTo-SqlFloat $parts[11]
    ConvertTo-SqlFloat $parts[12]
    ConvertTo-SqlFloat $parts[13]
    ConvertTo-SqlFloat $parts[14]
    ConvertTo-SqlFloat $parts[15]
    ConvertTo-SqlFloat $parts[16]
    ConvertTo-SqlFloat $parts[17]
    ConvertTo-SqlFloat $parts[18]
    ConvertTo-SqlFloat $parts[19]
    ConvertTo-SqlFloat $parts[20]
    ConvertTo-SqlFloat $parts[21]
    ConvertTo-SqlFloat $parts[22]
    ConvertTo-SqlFloat $parts[23]
    ConvertTo-SqlFloat $parts[24]
    ConvertTo-SqlFloat $parts[25]
  )

  $batchRows.Add('(' + ($rowValues -join ', ') + ')')
  $totalRows++

  if ($batchRows.Count -ge $BatchSize) {
    [void]$sb.AppendLine($insertHeader + ($batchRows -join ",`n") + ';')
    $batchRows.Clear()
  }
}

if ($batchRows.Count -gt 0) {
  [void]$sb.AppendLine($insertHeader + ($batchRows -join ",`n") + ';')
}

$sqlFile = Join-Path ([System.IO.Path]::GetTempPath()) 'load-test-fd004.generated.sql'
Set-Content -Path $sqlFile -Value $sb.ToString() -Encoding utf8
Write-Host "Script SQL generato: $sqlFile  (righe=$totalRows, batch=$BatchSize)"

# 3) Esegui lo script SQL con token Entra (passwordless)
az extension show --name rdbms-connect -o none 2>$null
if ($LASTEXITCODE -ne 0) { az extension add --name rdbms-connect --only-show-errors }

$upn = az ad signed-in-user show --query userPrincipalName -o tsv
$token = az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv
az postgres flexible-server execute `
  --name $server `
  --admin-user $upn `
  --admin-password $token `
  --database-name $DB `
  --file-path $sqlFile `
  --output table

Write-Host "Tabella $TableName creata e popolata da test_FD004.txt su $server/$DB."