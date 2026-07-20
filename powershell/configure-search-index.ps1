<#
.SYNOPSIS
    Creates the Azure AI Search resources required for the Engineering Copilot RAG pipeline.

.DESCRIPTION
    This script creates the following Azure AI Search resources via the Search REST API:
      - Data source  : ADLS Gen2 connection using managed identity (no keys)
      - Skillset     : SplitSkill for chunking + AzureOpenAIEmbeddingSkill for vectors
      - Index        : Vector-enabled index supporting keyword, semantic and hybrid search
      - Indexer      : Scheduled indexer that processes only *.md files

    Prerequisites:
      - The Bicep templates (deploy.bicep) must have been deployed successfully.
      - All Shared Private Link connections from Search to Storage and OpenAI must be
        approved (see docs/rag-ingestion-architecture.md).
      - The caller must have Search Service Contributor or Search Index Data Contributor
        RBAC on the Search service.
      - When the Search service has publicNetworkAccess: disabled, run this script from
        within the VNet (e.g. after connecting via P2S VPN).

.PARAMETER SearchServiceName
    Name of the Azure AI Search service (e.g. srchamamrodeve1234).

.PARAMETER SearchEndpoint
    HTTPS endpoint of the Search service (e.g. https://srchamamrodeve1234.search.windows.net).

.PARAMETER StorageAccountName
    Name of the ADLS Gen2 storage account (e.g. lakeamamrodeve1234).

.PARAMETER StorageAccountId
    Full Azure resource ID of the storage account.

.PARAMETER OpenAiEndpoint
    HTTPS endpoint of the Azure OpenAI / AI Services resource
    (e.g. https://aiamamrodeve1234.openai.azure.com).

.PARAMETER OpenAiResourceId
    Full Azure resource ID of the AI Services (OpenAI) account.

.PARAMETER EmbeddingDeploymentName
    Name of the embedding model deployment (default: text-embedding-3-large).

.PARAMETER IndexName
    Name to give to the Search index (default: engineering-docs).

.PARAMETER ContainerName
    Name of the ADLS Gen2 container that holds the .md source files
    (default: engineering-docs).

.PARAMETER ScheduleInterval
    ISO 8601 duration for the indexer schedule (default: PT1H = every hour).
    Set to empty string '' to disable scheduling (manual trigger only).

.PARAMETER SearchAdminKey
    Optional Azure AI Search admin key used for bootstrap operations. When omitted,
    the script authenticates with Microsoft Entra ID RBAC.

.EXAMPLE
    # Collect outputs from the Bicep deployment first:
    $out = az deployment sub show -n deploy --query properties.outputs -o json | ConvertFrom-Json

    .\configure-search-index.ps1 `
        -SearchServiceName   $out.engineeringSearchServiceName.value `
        -SearchEndpoint      $out.engineeringSearchEndpoint.value `
        -StorageAccountName  $out.dataLakeAccountName.value `
        -StorageAccountId    $out.dataLakeAccountId.value `
        -OpenAiEndpoint      $out.engineeringAiServicesEndpoint.value `
        -OpenAiResourceId    $out.engineeringAiServicesId.value
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SearchServiceName,

    [Parameter(Mandatory = $true)]
    [string]$SearchEndpoint,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountId,

    [Parameter(Mandatory = $true)]
    [string]$OpenAiEndpoint,

    [Parameter(Mandatory = $true)]
    [string]$OpenAiResourceId,

    [string]$EmbeddingDeploymentName = 'text-embedding-3-large',

    [string]$IndexName = 'engineering-docs',

    [string]$ContainerName = 'engineering-docs',

    [string]$ScheduleInterval = 'PT1H',

    [string]$SearchAdminKey = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Get-BearerToken {
    <#
    .SYNOPSIS Obtains a short-lived bearer token for the Search data-plane scope.
    Prefers the logged-in Azure CLI identity; falls back to environment variables.
    #>
    $token = (az account get-access-token --resource 'https://search.azure.com' --query accessToken -o tsv 2>$null)
    if (-not $token) {
        throw 'Could not obtain a bearer token. Run "az login" or ensure a managed identity is available.'
    }
    return $token
}

function Invoke-SearchApi {
    <#
    .SYNOPSIS Sends a PUT or GET request to the Azure AI Search REST API.
    #>
    param(
        [string]$Method,
        [string]$Path,
        [hashtable]$Body = @{},
        [switch]$IgnoreNotFound
    )
    $uri    = "$($SearchEndpoint.TrimEnd('/'))/$Path"
    $headers = if ($SearchAdminKey) {
        @{
            'api-key'      = $SearchAdminKey
            'Content-Type' = 'application/json'
        }
    }
    else {
        $token = Get-BearerToken
        @{
            Authorization  = 'Bearer ' + $token
            'Content-Type' = 'application/json'
        }
    }
    $params = @{
        Method  = $Method
        Uri     = $uri
        Headers = $headers
    }
    if ($Method -in 'PUT','POST') {
        $params.Body = ($Body | ConvertTo-Json -Depth 20 -Compress)
    }
    try {
        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        $statusCode = $_.Exception.Response?.StatusCode?.value__
        if ($IgnoreNotFound -and $statusCode -eq 404) {
            return $null
        }
        $detail     = $_.ErrorDetails?.Message
        Write-Error "Search API $Method $uri failed ($statusCode): $detail"
        throw
    }
}

Write-Host "`nResetting existing Search index resources for '$IndexName' if present..." -ForegroundColor Cyan
Invoke-SearchApi -Method DELETE -Path "indexers/$($IndexName)-ix?api-version=2024-07-01" -IgnoreNotFound | Out-Null
Invoke-SearchApi -Method DELETE -Path "skillsets/$($IndexName)-ss?api-version=2024-07-01" -IgnoreNotFound | Out-Null
Invoke-SearchApi -Method DELETE -Path "indexes/$($IndexName)?api-version=2024-07-01" -IgnoreNotFound | Out-Null

# ---------------------------------------------------------------------------
# 1. Data Source
# ---------------------------------------------------------------------------

Write-Host "`n[1/4] Creating data source '$IndexName-ds'..." -ForegroundColor Cyan

$dataSourceBody = @{
    name        = "$IndexName-ds"
    type        = 'azureblob'
    credentials = @{
        connectionString = "ResourceId=$StorageAccountId;"
    }
    container   = @{
        name  = $ContainerName
    }
    dataDeletionDetectionPolicy = $null
    dataChangeDetectionPolicy   = @{
        '@odata.type' = '#Microsoft.Azure.Search.HighWaterMarkChangeDetectionPolicy'
        highWaterMarkColumnName = 'metadata_storage_last_modified'
    }
}

if ($PSCmdlet.ShouldProcess("$IndexName-ds", 'Create data source')) {
    Invoke-SearchApi -Method PUT -Path "datasources/$($IndexName)-ds?api-version=2024-07-01" -Body $dataSourceBody
    Write-Host "  Data source created." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2. Index (vector-enabled, semantic, keyword, hybrid)
# ---------------------------------------------------------------------------

Write-Host "`n[2/4] Creating index '$IndexName'..." -ForegroundColor Cyan

# text-embedding-3-large produces 3072-dimensional vectors by default.
$vectorDimensions = 3072

$indexBody = @{
    name   = $IndexName
    fields = @(
        @{ name = 'id';                       type = 'Edm.String';                  key = $true;  searchable = $true;  filterable = $true;  sortable = $true;  facetable = $false; retrievable = $true; analyzer = 'keyword' }
        @{ name = 'parent_id';                type = 'Edm.String';                  key = $false; searchable = $false; filterable = $true;  sortable = $false; facetable = $false; retrievable = $true }
        @{ name = 'chunk_id';                 type = 'Edm.String';                  key = $false; searchable = $false; filterable = $true;  sortable = $false; facetable = $false; retrievable = $true }
        @{ name = 'content';                  type = 'Edm.String';                  key = $false; searchable = $true;  filterable = $false; sortable = $false; facetable = $false; retrievable = $true; analyzer = 'standard.lucene' }
        @{ name = 'metadata_storage_name';    type = 'Edm.String';                  key = $false; searchable = $true;  filterable = $true;  sortable = $true;  facetable = $false; retrievable = $true }
        @{ name = 'metadata_storage_path';    type = 'Edm.String';                  key = $false; searchable = $false; filterable = $true;  sortable = $false; facetable = $false; retrievable = $true }
        @{ name = 'metadata_storage_content_type'; type = 'Edm.String';             key = $false; searchable = $false; filterable = $true;  sortable = $false; facetable = $false; retrievable = $true }
        @{ name = 'metadata_storage_last_modified'; type = 'Edm.DateTimeOffset';    key = $false; searchable = $false; filterable = $true;  sortable = $true;  facetable = $false; retrievable = $true }
        @{
            name       = 'content_vector'
            type       = 'Collection(Edm.Single)'
            searchable = $true
            retrievable = $false
            dimensions = $vectorDimensions
            vectorSearchProfile = 'hnsw-profile'
        }
    )
    vectorSearch = @{
        profiles   = @(
            @{
                name        = 'hnsw-profile'
                algorithm   = 'hnsw-config'
                vectorizer  = 'openai-vectorizer'
            }
        )
        algorithms = @(
            @{
                name = 'hnsw-config'
                kind = 'hnsw'
                hnswParameters = @{
                    metric         = 'cosine'
                    m              = 4
                    efConstruction = 400
                    efSearch       = 500
                }
            }
        )
        vectorizers = @(
            @{
                name = 'openai-vectorizer'
                kind = 'azureOpenAI'
                azureOpenAIParameters = @{
                    resourceUri      = $OpenAiEndpoint.TrimEnd('/')
                    deploymentId     = $EmbeddingDeploymentName
                    modelName        = 'text-embedding-3-large'
                    # DataNoneIdentity tells Search to use its own system-assigned managed
                    # identity when issuing query-time embedding calls to Azure OpenAI.
                    authIdentity     = @{
                        '@odata.type' = '#Microsoft.Azure.Search.DataNoneIdentity'
                    }
                }
            }
        )
    }
    semantic = @{
        defaultConfiguration = 'semantic-config'
        configurations       = @(
            @{
                name = 'semantic-config'
                prioritizedFields = @{
                    prioritizedContentFields = @(
                        @{ fieldName = 'content' }
                    )
                    titleField     = @{ fieldName = 'metadata_storage_name' }
                    prioritizedKeywordsFields = @()
                }
            }
        )
    }
}

if ($PSCmdlet.ShouldProcess($IndexName, 'Create index')) {
    Invoke-SearchApi -Method PUT -Path "indexes/$($IndexName)?api-version=2024-07-01" -Body $indexBody
    Write-Host "  Index created." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 3. Skillset
# ---------------------------------------------------------------------------

Write-Host "`n[3/4] Creating skillset '$IndexName-ss'..." -ForegroundColor Cyan

$skillsetBody = @{
    name        = "$IndexName-ss"
    description = 'Splits Markdown documents into chunks and generates embeddings using Azure OpenAI.'
    skills      = @(
        @{
            '@odata.type'    = '#Microsoft.Skills.Text.SplitSkill'
            name             = 'split-skill'
            description      = 'Splits document text into overlapping pages suitable for vector search.'
            context          = '/document'
            defaultLanguageCode = 'en'
            textSplitMode    = 'pages'
            maximumPageLength = 2000
            pageOverlapLength = 200
            inputs           = @(
                @{ name = 'text'; source = '/document/content' }
            )
            outputs          = @(
                @{ name = 'textItems'; targetName = 'pages' }
            )
        }
        @{
            '@odata.type'    = '#Microsoft.Skills.Text.AzureOpenAIEmbeddingSkill'
            name             = 'embedding-skill'
            description      = 'Generates embeddings for each chunk using Azure OpenAI text-embedding-3-large.'
            context          = '/document/pages/*'
            resourceUri      = $OpenAiEndpoint.TrimEnd('/')
            deploymentId     = $EmbeddingDeploymentName
            modelName        = 'text-embedding-3-large'
            dimensions       = $vectorDimensions
            # DataNoneIdentity instructs Search to authenticate to Azure OpenAI using
            # its own system-assigned managed identity (not an API key).
            authIdentity     = @{
                '@odata.type' = '#Microsoft.Azure.Search.DataNoneIdentity'
            }
            inputs           = @(
                @{ name = 'text'; source = '/document/pages/*' }
            )
            outputs          = @(
                @{ name = 'embedding'; targetName = 'content_vector' }
            )
        }
    )
    indexProjections = @{
        selectors = @(
            @{
                targetIndexName    = $IndexName
                parentKeyFieldName = 'parent_id'
                sourceContext      = '/document/pages/*'
                mappings           = @(
                    @{ name = 'content';        source = '/document/pages/*' }
                    @{ name = 'content_vector'; source = '/document/pages/*/content_vector' }
                    @{ name = 'metadata_storage_name'; source = '/document/metadata_storage_name' }
                    @{ name = 'metadata_storage_path'; source = '/document/metadata_storage_path' }
                    @{ name = 'metadata_storage_content_type'; source = '/document/metadata_storage_content_type' }
                    @{ name = 'metadata_storage_last_modified'; source = '/document/metadata_storage_last_modified' }
                )
            }
        )
        parameters = @{
            projectionMode = 'skipIndexingParentDocuments'
        }
    }
}

if ($PSCmdlet.ShouldProcess("$IndexName-ss", 'Create skillset')) {
    Invoke-SearchApi -Method PUT -Path "skillsets/$($IndexName)-ss?api-version=2024-07-01" -Body $skillsetBody
    Write-Host "  Skillset created." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 4. Indexer
# ---------------------------------------------------------------------------

Write-Host "`n[4/4] Creating indexer '$IndexName-ix'..." -ForegroundColor Cyan

$scheduleProperty = if ($ScheduleInterval) {
    @{ interval = $ScheduleInterval; startTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
} else {
    $null
}

$indexerBody = @{
    name            = "$IndexName-ix"
    description     = 'Indexes Markdown files from the engineering-docs ADLS Gen2 container.'
    dataSourceName  = "$IndexName-ds"
    targetIndexName = $IndexName
    skillsetName    = "$IndexName-ss"
    schedule        = $scheduleProperty
    parameters      = @{
        batchSize             = 1
        maxFailedItems        = 10
        maxFailedItemsPerBatch = 10
        configuration         = @{
            dataToExtract             = 'contentAndMetadata'
            indexedFileNameExtensions = '.md'
            parsingMode               = 'text'
            indexStorageMetadataOnlyForOversizedDocuments = $true
        }
    }
    fieldMappings = @(
        @{ sourceFieldName = 'metadata_storage_name'; targetFieldName = 'metadata_storage_name' }
        @{ sourceFieldName = 'metadata_storage_path'; targetFieldName = 'metadata_storage_path' }
        @{ sourceFieldName = 'metadata_storage_content_type'; targetFieldName = 'metadata_storage_content_type' }
        @{ sourceFieldName = 'metadata_storage_last_modified'; targetFieldName = 'metadata_storage_last_modified' }
    )
    outputFieldMappings = @()
}

if ($PSCmdlet.ShouldProcess("$IndexName-ix", 'Create indexer')) {
    Invoke-SearchApi -Method PUT -Path "indexers/$($IndexName)-ix?api-version=2024-07-01" -Body $indexerBody
    Write-Host "  Indexer created." -ForegroundColor Green
}

Write-Host "`nAll Search resources created successfully." -ForegroundColor Green
Write-Host "Run 'az search indexer run --service-name $SearchServiceName --name $IndexName-ix' to trigger the first indexing run." -ForegroundColor Yellow
