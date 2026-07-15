# RAG Ingestion Architecture — Engineering Copilot

This document describes the Azure AI Search ingestion pipeline for the **Engineering Copilot** RAG scenario: reading Markdown documents from ADLS Gen2, chunking them, generating embeddings via Azure OpenAI, and populating a vector-enabled search index — all over Private Link.

---

## 1. Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Azure Resource Group (ama-mro-playground)                              │
│                                                                         │
│  ┌──────────────────────┐        ┌──────────────────────────────────┐  │
│  │  ADLS Gen2           │        │  Azure AI Services (OpenAI)      │  │
│  │  datalakeamamro---   │        │  aiamamrodeve---                 │  │
│  │  container:          │        │  - chat model (GPT-5.6 Sol)      │  │
│  │   engineering-docs   │        │  - embedding model               │  │
│  │  *.md files          │        │    (text-embedding-3-large)      │  │
│  │  publicNetAccess:    │        │  publicNetAccess: Disabled       │  │
│  │   Disabled           │        │  disableLocalAuth: true          │  │
│  └──────────┬───────────┘        └──────────────┬───────────────────┘  │
│             │                                    │                      │
│             │  Shared Private Link (blob)        │  Shared Private Link │
│             │  ◄──────────────────────────       │  (openAI) ◄──────── │
│             │                         │          │             │        │
│  ┌──────────▼──────────────────────────────────────────────────▼────┐  │
│  │  Azure AI Search  (srchamamrodeve---)                            │  │
│  │  SKU: Standard                                                   │  │
│  │  System-assigned managed identity                                │  │
│  │  publicNetAccess: disabled (private endpoint only)               │  │
│  │                                                                  │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────┐  ┌────────┐  │  │
│  │  │  Data Source │  │  Skillset    │  │  Index   │  │Indexer │  │  │
│  │  │  (ds)        │  │  (ss)        │  │  (idx)   │  │  (ix)  │  │  │
│  │  │  ADLS Gen2   │  │  SplitSkill  │  │  vector  │  │ sched. │  │  │
│  │  │  *.md filter │  │  Embedding   │  │  semantic│  │ hourly │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────┘  └────────┘  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  RBAC assignments on Search managed identity:                          │
│  - Storage Blob Data Reader  → ADLS Gen2                               │
│  - Cognitive Services OpenAI User → AI Services                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### Components and Their Roles

| Component | Resource Type | Purpose |
|---|---|---|
| ADLS Gen2 (`engineering-docs` container) | `Microsoft.Storage/storageAccounts` | Source of *.md documents |
| Azure AI Services | `Microsoft.CognitiveServices/accounts` | Hosts the `text-embedding-3-large` embedding deployment |
| Azure AI Search | `Microsoft.Search/searchServices` | Runs the indexing pipeline; stores the vector index |
| Data source | Search REST resource | Reads *.md blobs from ADLS Gen2 |
| Skillset | Search REST resource | Chunks text (SplitSkill) and generates embeddings (AzureOpenAIEmbeddingSkill) |
| Index | Search REST resource | Vector-enabled index supporting keyword, semantic and hybrid search |
| Indexer | Search REST resource | Scheduled (hourly) driver that pulls new/changed docs through the pipeline |

---

## 2. Network Flow

All communication between Azure AI Search, ADLS Gen2 and Azure OpenAI is private. No traffic traverses the public internet.

```
Upload .md → ADLS Gen2 (private endpoint in spoke VNet, 10.13.2.5)
                │
                │  Shared Private Link (blob)
                │  [managed by Azure AI Search outbound SPL]
                ▼
          Azure AI Search reads the document via the SPL connection
                │
                │  Indexer invokes SplitSkill (in-process)
                │
                │  Indexer invokes AzureOpenAIEmbeddingSkill
                │  Shared Private Link (openAI)
                │  [managed by Azure AI Search outbound SPL]
                ▼
          Azure OpenAI embedding endpoint (private, via SPL)
                │
                └──► Embedding vector returned to Search
                │
                ▼
          Chunk + vector written to the Search index
```

### Networking Resources Created by the Bicep Templates

| Resource | Type | Purpose |
|---|---|---|
| `spl-storage-blob` | `Microsoft.Search/searchServices/sharedPrivateLinkResources` | Outbound private link: Search → ADLS Gen2 blob endpoint |
| `spl-openai` | `Microsoft.Search/searchServices/sharedPrivateLinkResources` | Outbound private link: Search → Azure OpenAI endpoint |
| PE for Search (`pe-hangarmind-srch...-searchService`) | `Microsoft.Network/privateEndpoints` | Inbound private endpoint so clients reach Search privately (created by `deploy-ai-private-endpoints.bicep`) |
| PE for ADLS Gen2 blob/dfs | `Microsoft.Network/privateEndpoints` | Inbound private endpoint for storage (created by `deploy-private-endpoints.bicep`) |
| PE for AI Services | `Microsoft.Network/privateEndpoints` | Inbound private endpoint for Azure OpenAI (created by `deploy-ai-private-endpoints.bicep`) |

---

## 3. RBAC Configuration

### Search Service Managed Identity → ADLS Gen2

| Setting | Value |
|---|---|
| Principal | Azure AI Search system-assigned managed identity |
| Role | **Storage Blob Data Reader** (`2a2b9908-6ea1-4ae2-8e65-a410df84e7d1`) |
| Scope | ADLS Gen2 storage account |
| Set by | `deploy-ai.bicep` (resource `searchStorageBlobDataReader`) |

This role allows the indexer to read `.md` blobs from the `engineering-docs` container without a storage key. The storage account has `allowSharedKeyAccess: false`, so key-based access is unavailable by design.

### Search Service Managed Identity → Azure OpenAI

| Setting | Value |
|---|---|
| Principal | Azure AI Search system-assigned managed identity |
| Role | **Cognitive Services OpenAI User** (`5e0bd9bd-7b93-4f28-af87-19fc36ad61bd`) |
| Scope | Azure AI Services (OpenAI) account |
| Set by | `deploy-ai.bicep` (resource `searchOpenAiUser`) |

This role allows the skillset's `AzureOpenAIEmbeddingSkill` to call the embedding endpoint using managed identity — no API key required (`disableLocalAuth: true` on AI Services).

### Backend Application Identity → Search

| Role | Purpose |
|---|---|
| Search Service Contributor | Manage index schema and service settings |
| Search Index Data Contributor | Read and write index documents |

These roles are granted on the Azure AI Search service to the backend container app managed identity (`backendPrincipalId`) via `deploy-ai.bicep`.

---

## 4. Deployment Steps

### Step 1 — Deploy Infrastructure

```bash
cd bicep

az deployment sub create \
  --name deploy \
  --location francecentral \
  --template-file deploy.bicep \
  --parameters \
    resourceGroupName=ama-mro-playground \
    deployerObjectId=$(az ad signed-in-user show --query id -o tsv) \
    deployerPrincipalName=$(az ad signed-in-user show --query userPrincipalName -o tsv)
```

Key resources created by this deployment:
- ADLS Gen2 with `publicNetworkAccess: Disabled` (when `deployPrivateEndpoints=true`)
- Azure AI Search (Standard SKU) with system-assigned managed identity
- RBAC: Search MI → Storage Blob Data Reader, Search MI → Cognitive Services OpenAI User
- Shared Private Links (both start in `Pending` state — see Step 2)
- Private endpoints + DNS zones for Search and AI Services

### Step 2 — Approve Shared Private Link Connections

Shared Private Links created by the Search service appear as pending private endpoint connections on the target resources and must be approved before indexing can proceed.

**Approve connection from Search to Storage:**
```bash
# Get connection details
STORAGE_ACCOUNT=$(az deployment sub show -n deploy \
  --query properties.outputs.dataLakeAccountName.value -o tsv)

# List pending connections
az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --query privateEndpointConnections[].{name:name,state:privateLinkServiceConnectionState.status}

# Approve the pending connection
CONNECTION_NAME=$(az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --query "privateEndpointConnections[?privateLinkServiceConnectionState.status=='Pending'].name" \
  -o tsv)

az storage account private-endpoint-connection approve \
  --account-name "$STORAGE_ACCOUNT" \
  --name "$CONNECTION_NAME" \
  --description "Approved for Azure AI Search indexing"
```

**Approve connection from Search to Azure OpenAI:**
```bash
AI_SERVICES_NAME=$(az deployment sub show -n deploy \
  --query properties.outputs.engineeringAiServicesName.value -o tsv)

CONNECTION_NAME=$(az cognitiveservices account show \
  --name "$AI_SERVICES_NAME" \
  --resource-group ama-mro-playground \
  --query "properties.privateEndpointConnections[?privateLinkServiceConnectionState.status=='Pending'].name" \
  -o tsv)

az cognitiveservices account private-endpoint-connection approve \
  --resource-group ama-mro-playground \
  --account-name "$AI_SERVICES_NAME" \
  --name "$CONNECTION_NAME"
```

### Step 3 — Configure the Search Index

Connect via P2S VPN (or use Azure Cloud Shell / a jumpbox in the spoke VNet), then run:

```powershell
# Collect Bicep outputs
$out = az deployment sub show -n deploy --query properties.outputs -o json | ConvertFrom-Json

.\powershell\configure-search-index.ps1 `
    -SearchServiceName  $out.engineeringSearchServiceName.value `
    -SearchEndpoint     $out.engineeringSearchEndpoint.value `
    -StorageAccountName $out.dataLakeAccountName.value `
    -StorageAccountId   $out.dataLakeAccountId.value `
    -OpenAiEndpoint     $out.engineeringAiServicesEndpoint.value `
    -OpenAiResourceId   $out.engineeringAiServicesId.value
```

The script creates:
1. **Data source** — ADLS Gen2 connection using managed identity (`ResourceId=...` connection string, no key)
2. **Index** — vector-enabled with HNSW algorithm, semantic configuration and 3072-dimension vectors
3. **Skillset** — `SplitSkill` (chunks at 2000 chars / 200 char overlap) + `AzureOpenAIEmbeddingSkill`
4. **Indexer** — runs every hour, processes only `.md` files

### Step 4 — Upload Documents and Trigger Indexing

```bash
# Connect via P2S VPN first (storage has public access disabled)

az storage blob upload-batch \
  --account-name "$STORAGE_ACCOUNT" \
  --destination engineering-docs \
  --source ./data-sample \
  --pattern "*.md" \
  --auth-mode login

# Trigger an immediate run (optional — indexer is also scheduled hourly)
SEARCH_NAME=$(az deployment sub show -n deploy \
  --query properties.outputs.engineeringSearchServiceName.value -o tsv)

az search indexer run \
  --service-name "$SEARCH_NAME" \
  --resource-group ama-mro-playground \
  --name engineering-docs-ix
```

---

## 5. Validation Steps

### 5.1 Verify Shared Private Links Are Approved

```bash
# Check SPL status on the Search service
az rest \
  --method GET \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/ama-mro-playground/providers/Microsoft.Search/searchServices/$SEARCH_NAME/sharedPrivateLinkResources?api-version=2023-11-01" \
  --query "value[].{name:name,status:properties.status,resourceId:properties.privateLinkResourceId}"
```

Expected output: `"status": "Approved"` for both connections.

### 5.2 Verify RBAC Assignments

```bash
SEARCH_MI=$(az deployment sub show -n deploy \
  --query properties.outputs.engineeringSearchManagedIdentityPrincipalId.value -o tsv)

# Storage Blob Data Reader on ADLS Gen2
az role assignment list \
  --assignee "$SEARCH_MI" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/ama-mro-playground/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT" \
  --query "[].roleDefinitionName"

# Cognitive Services OpenAI User on AI Services
az role assignment list \
  --assignee "$SEARCH_MI" \
  --all \
  --query "[?roleDefinitionName=='Cognitive Services OpenAI User'].{scope:scope,role:roleDefinitionName}"
```

### 5.3 Verify Indexer Status

```bash
# From within the VNet
az search indexer show \
  --service-name "$SEARCH_NAME" \
  --resource-group ama-mro-playground \
  --name engineering-docs-ix \
  --query "{status:status,lastResult:lastResult.status,errors:lastResult.errors}"
```

Expected: `"status": "running"` or `"status": "success"`.

### 5.4 Test a Hybrid Search Query

```bash
# az rest automatically uses the signed-in Azure CLI identity (no manual token handling)
SEARCH_ENDPOINT=$(az deployment sub show -n deploy \
  --query properties.outputs.engineeringSearchEndpoint.value -o tsv)

az rest \
  --method POST \
  --url "${SEARCH_ENDPOINT}/indexes/engineering-docs/docs/search?api-version=2024-07-01" \
  --resource "https://search.azure.com" \
  --body '{
    "search": "EASA maintenance procedure",
    "queryType": "semantic",
    "semanticConfiguration": "semantic-config",
    "vectorQueries": [
      {
        "kind": "text",
        "text": "EASA maintenance procedure",
        "fields": "content_vector",
        "k": 5
      }
    ],
    "select": "metadata_storage_name,content,parent_id",
    "top": 5
  }'
```

---

## 6. Troubleshooting

### Indexer reports "Forbidden" or "Access denied" on Storage

**Symptom:** Indexer execution status shows an error like `403 Forbidden` when reading blobs.

**Checks:**
1. Verify the Storage Blob Data Reader RBAC is assigned to the Search managed identity (Step 5.2 above).
2. Verify the Shared Private Link `spl-storage-blob` is in `Approved` state (Step 5.1).
3. Confirm RBAC propagation has completed — it can take up to 5 minutes after assignment.
4. Check that the storage account's `allowSharedKeyAccess` is `false` and that the data source connection string uses `ResourceId=...` (not an account key).

### Indexer reports "Unauthorized" when calling the embedding skill

**Symptom:** Indexer execution status shows an error from the `AzureOpenAIEmbeddingSkill`.

**Checks:**
1. Verify the Cognitive Services OpenAI User RBAC is assigned to the Search managed identity (Step 5.2).
2. Verify the Shared Private Link `spl-openai` is in `Approved` state (Step 5.1).
3. Confirm the AI Services resource has `disableLocalAuth: true` — when this is set, only Entra tokens are accepted and the skillset must use `authIdentity: {"@odata.type": "#Microsoft.Azure.Search.DataNoneIdentity"}` (which tells Search to use its own managed identity).

### Search service is unreachable after deployment

**Symptom:** Calls to `https://srch....search.windows.net` time out or receive connection refused.

**Root cause:** `publicNetworkAccess: disabled` is set on the Search service when `deployPrivateEndpoints = true`. All access must go through the private endpoint.

**Fix:** Connect via the P2S VPN gateway (`hangarvpn.<region>.cloudapp.azure.com`) before calling the Search REST API or running `az search` commands.

### Shared Private Link remains in "Pending" state after deployment

**Symptom:** `az rest` query shows `"status": "Pending"` for the SPL.

**Fix:** Manually approve the private endpoint connection on the target resource (see Step 2). Approval cannot be automated in a Bicep template; it requires an explicit `approve` call on the target resource.

### Indexer processes 0 documents

**Symptom:** Indexer runs successfully but reports 0 documents processed.

**Checks:**
1. Confirm `.md` files exist in the `engineering-docs` container: `az storage blob list --account-name ... --container-name engineering-docs --auth-mode login`.
2. Check that the data source `query` field is set to `*.md`. If changed, reset the indexer high-water mark: `az search indexer reset --service-name ... --name engineering-docs-ix`.
3. Review the indexer execution history for item-level errors: `az search indexer show --service-name ... --name engineering-docs-ix`.

### SKU does not support Shared Private Links

**Symptom:** Deployment fails with: _The SKU 'basic' does not support shared private link resources._

**Fix:** Azure AI Search Shared Private Links require **Standard SKU or higher**. The Bicep templates default to `standard`. If you overrode the SKU to `basic` or `free`, update the `engineeringSearchSku` parameter in `deploy.bicep` to `standard`.
