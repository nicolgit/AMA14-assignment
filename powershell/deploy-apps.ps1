[CmdletBinding(DefaultParameterSetName = 'Deploy')]
param(
    [string]$ResourceGroupName = 'ama-mro-playground',
    [string]$DeploymentName = 'deploy',
    [string]$AcrName,
    [string]$BackendAppName,
    [string]$FrontendAppName,

    [Parameter(ParameterSetName = 'Deploy')]
    [ValidatePattern('^[a-z0-9](?:[a-z0-9.-]{0,126}[a-z0-9])?$')]
    [string]$Tag,

    [Parameter(Mandatory, ParameterSetName = 'Rollback')]
    [ValidatePattern('^[a-z0-9](?:[a-z0-9.-]{0,126}[a-z0-9])?$')]
    [string]$RollbackTag,

    [switch]$SkipSmokeTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$env:PYTHONUTF8 = '1'

function Invoke-AzureCli {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = & az @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed: az $($Arguments -join ' ')"
    }

    return ($output | Out-String).Trim()
}

function Resolve-SingleName {
    param(
        [string]$ProvidedName,
        [string]$ResourceType,
        [string]$NamePrefix
    )

    if ($ProvidedName) {
        return $ProvidedName
    }

    $query = "[?starts_with(name, '$NamePrefix')].name"
    $json = Invoke-AzureCli @(
        'resource', 'list',
        '--resource-group', $ResourceGroupName,
        '--resource-type', $ResourceType,
        '--query', $query,
        '--output', 'json'
    )
    $names = @($json | ConvertFrom-Json)

    if ($names.Count -ne 1) {
        throw "Expected exactly one $ResourceType resource starting with '$NamePrefix' in '$ResourceGroupName'; found $($names.Count). Pass its name explicitly."
    }

    return [string]$names[0]
}

function Test-HttpEndpoint {
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    for ($attempt = 1; $attempt -le 12; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri $Uri -TimeoutSec 20
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) {
                Write-Host "Smoke test passed: $Uri"
                return
            }
        }
        catch {
            if ($attempt -eq 12) {
                throw "Smoke test failed after $attempt attempts: $Uri. $($_.Exception.Message)"
            }
        }

        Start-Sleep -Seconds 5
    }
}

function Test-AcrImageExists {
    param(
        [Parameter(Mandatory)]
        [string]$Image
    )

    & az acr repository show --name $AcrName --image $Image --output none 2>$null
    return $LASTEXITCODE -eq 0
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required but was not found in PATH.'
}

Invoke-AzureCli @('account', 'show', '--output', 'none') | Out-Null

$deploymentOutputsJson = Invoke-AzureCli @('deployment', 'sub', 'show', '--name', $DeploymentName, '--query', 'properties.outputs', '--output', 'json')
$deploymentOutputs = $deploymentOutputsJson | ConvertFrom-Json

if (-not $AcrName -and $deploymentOutputs.containerRegistryName.value) {
    $AcrName = [string]$deploymentOutputs.containerRegistryName.value
}
if (-not $BackendAppName -and $deploymentOutputs.backendApiAppName.value) {
    $BackendAppName = [string]$deploymentOutputs.backendApiAppName.value
}
if (-not $FrontendAppName -and $deploymentOutputs.frontendSpaAppName.value) {
    $FrontendAppName = [string]$deploymentOutputs.frontendSpaAppName.value
}

$AcrName = Resolve-SingleName -ProvidedName $AcrName -ResourceType 'Microsoft.ContainerRegistry/registries' -NamePrefix 'acr'
$BackendAppName = Resolve-SingleName -ProvidedName $BackendAppName -ResourceType 'Microsoft.App/containerApps' -NamePrefix 'api-'
$FrontendAppName = Resolve-SingleName -ProvidedName $FrontendAppName -ResourceType 'Microsoft.App/containerApps' -NamePrefix 'web-'

$acrLoginServer = Invoke-AzureCli @('acr', 'show', '--name', $AcrName, '--query', 'loginServer', '--output', 'tsv')
$backendFqdn = Invoke-AzureCli @('containerapp', 'show', '--resource-group', $ResourceGroupName, '--name', $BackendAppName, '--query', 'properties.configuration.ingress.fqdn', '--output', 'tsv')
$frontendFqdn = Invoke-AzureCli @('containerapp', 'show', '--resource-group', $ResourceGroupName, '--name', $FrontendAppName, '--query', 'properties.configuration.ingress.fqdn', '--output', 'tsv')

if ($PSCmdlet.ParameterSetName -eq 'Rollback') {
    $effectiveTag = $RollbackTag
    Write-Host "Rolling back both applications to tag '$effectiveTag'."

    if (-not (Test-AcrImageExists -Image "hangarmind/api:$effectiveTag")) {
        throw "API image tag '$effectiveTag' does not exist in ACR '$AcrName'."
    }
    if (-not (Test-AcrImageExists -Image "hangarmind/web:$effectiveTag")) {
        throw "SPA image tag '$effectiveTag' does not exist in ACR '$AcrName'."
    }
}
else {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $apiPath = Join-Path $repoRoot 'code\hm-api'
    $webPath = Join-Path $repoRoot 'code\hm-app'

    if (-not $Tag) {
        $commit = (& git -C $repoRoot rev-parse --short=12 HEAD).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to determine the current Git commit. Pass -Tag explicitly.'
        }
        $Tag = "$commit-$(Get-Date -AsUTC -Format 'yyyyMMddHHmmss')"
    }
    $effectiveTag = $Tag

    if ((Test-AcrImageExists -Image "hangarmind/api:$effectiveTag") -or (Test-AcrImageExists -Image "hangarmind/web:$effectiveTag")) {
        throw "Tag '$effectiveTag' already exists in ACR '$AcrName'. Choose a new tag; deployment tags are immutable."
    }

    Write-Host "Building immutable application images with tag '$effectiveTag'."
    Invoke-AzureCli @(
        'acr', 'build',
        '--registry', $AcrName,
        '--image', "hangarmind/api:$effectiveTag",
        '--file', (Join-Path $apiPath 'Dockerfile'),
        '--platform', 'linux/amd64',
        '--no-logs',
        '--query', '{runId:runId,status:status,images:outputImages[].{repository:repository,tag:tag,digest:digest}}',
        '--output', 'json',
        $apiPath
    ) | Out-Host

    Invoke-AzureCli @(
        'acr', 'build',
        '--registry', $AcrName,
        '--image', "hangarmind/web:$effectiveTag",
        '--file', (Join-Path $webPath 'Dockerfile'),
        '--build-arg', "VITE_API_BASE_URL=https://$backendFqdn",
        '--platform', 'linux/amd64',
        '--no-logs',
        '--query', '{runId:runId,status:status,images:outputImages[].{repository:repository,tag:tag,digest:digest}}',
        '--output', 'json',
        $webPath
    ) | Out-Host
}

$apiImage = "$acrLoginServer/hangarmind/api:$effectiveTag"
$webImage = "$acrLoginServer/hangarmind/web:$effectiveTag"
$revisionSuffix = "r$(Get-Date -AsUTC -Format 'yyyyMMddHHmmss')"

Invoke-AzureCli @('containerapp', 'revision', 'set-mode', '--resource-group', $ResourceGroupName, '--name', $BackendAppName, '--mode', 'single', '--output', 'none') | Out-Null
Invoke-AzureCli @('containerapp', 'revision', 'set-mode', '--resource-group', $ResourceGroupName, '--name', $FrontendAppName, '--mode', 'single', '--output', 'none') | Out-Null

Write-Host "Updating backend to $apiImage"
Invoke-AzureCli @(
    'containerapp', 'update',
    '--resource-group', $ResourceGroupName,
    '--name', $BackendAppName,
    '--image', $apiImage,
    '--revision-suffix', $revisionSuffix,
    '--output', 'none'
) | Out-Null

if (-not $SkipSmokeTest) {
    Test-HttpEndpoint -Uri "https://$backendFqdn/health"
}

Write-Host "Updating frontend to $webImage"
Invoke-AzureCli @(
    'containerapp', 'update',
    '--resource-group', $ResourceGroupName,
    '--name', $FrontendAppName,
    '--image', $webImage,
    '--revision-suffix', $revisionSuffix,
    '--output', 'none'
) | Out-Null

if (-not $SkipSmokeTest) {
    Test-HttpEndpoint -Uri "https://$frontendFqdn/healthz"
}

Write-Host "Deployment completed with tag '$effectiveTag'."
Write-Host "API: https://$backendFqdn"
Write-Host "SPA: https://$frontendFqdn"
Write-Host "Rollback: .\powershell\deploy-apps.ps1 -RollbackTag $effectiveTag"