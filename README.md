> AMA14-assignment - Azure Master Architect Assignemnt 14 - nicold

## HangarMind

**HangarMind** is an AI-powered MRO (Maintenance, Repair & Overhaul) intelligence platform for a European aircraft maintenance provider servicing aircrafts across 6 carriers, operating in France, Germany, the United Kingdom, Spain and the Netherlands under GDPR and EU AI Act constraints.

### Objective

Turn reactive, fragmented maintenance into a predictive, governed model along four levers:

- **Predict maintenance requirements** — a Remaining Useful Life (RUL) model analyzes engine telemetry across the OEMs' proprietary data formats, reducing unscheduled events and cutting Aircraft-on-Ground (AOG) time from ~11 hours to under 3.
- **Optimize spare parts supply** — demand forecasting aligns stock across the 12 hangars, eliminating component cannibalization and improving point-of-use parts availability by 34%.
- **Automate EASA documentation** — a Gen AI assistant retrieves maintenance procedures and compiles EASA task cards from structured voice input, cutting documentation engineering effort by 55% (~4,500 man-hours/year).
- **Preserve engineering expertise** — codifies and makes senior engineers' knowledge searchable, mitigating the knowledge-loss risk (31% of engineers approaching retirement).

### Expected outcomes

| Metric | From | To |
|---|---|---|
| AOG time per event | 11 h | < 3 h |
| Point-of-use parts availability | — | +34% |
| EASA documentation effort | baseline | −55% |
| First-time-fix rate | 71% | 89% |

### Environment deployment instructions

The environment is deployed from the subscription-scoped Bicep template in `bicep/deploy.bicep`. The template creates the resource group and provisions the HangarMind Azure environment.

1. Sign in to Azure and select the target subscription:

	```powershell
	az login
	az account set --subscription "<subscription-id-or-name>"
	```

2. Collect the Microsoft Entra values required by the deployment. The Bicep template uses them to grant the deployer access to storage, PostgreSQL administration, and the VPN Gateway profile download:

	```powershell
	$deployerObjectId = az ad signed-in-user show --query id -o tsv
	$deployerPrincipalName = az ad signed-in-user show --query userPrincipalName -o tsv
	```

3. Validate the deployment with a `what-if` run before creating resources:

	```powershell
	az deployment sub what-if `
	  --location francecentral `
	  --template-file .\bicep\deploy.bicep `
	  --parameters deployerObjectId=$deployerObjectId `
						deployerPrincipalName=$deployerPrincipalName `
						postgresAdminPassword="<strong-password>"
	```

4. Deploy the environment:

	```powershell
	az deployment sub create `
	  --name deploy `
	  --location francecentral `
	  --template-file .\bicep\deploy.bicep `
	  --parameters deployerObjectId=$deployerObjectId `
						deployerPrincipalName=$deployerPrincipalName `
						postgresAdminPassword="<strong-password>"
	```

	The default resource group is `ama-mro-playground`. Override `resourceGroupName`, `location`, or any optional deployment flags only when you need a different environment shape.

5. After the deployment completes, download the Azure VPN Client configuration from the deployed Virtual Network Gateway and connect your workstation to the P2S VPN. This is required because the environment uses private endpoints and disables public network access for several data-plane services.

6. From the connected workstation, run the upload orchestrator. It creates and populates PostgreSQL tables, uploads C-MAPSS training data and maintenance documents to the Data Lake, starts the Azure ML train/evaluate pipeline, approves the pending Azure AI Search shared private link connections, and configures the Azure AI Search data source, index, skillset, and indexer:

	```powershell
	cd .\powershell
	.\upload.ps1 -RG ama-mro-playground
	```

	If the subscription deployment was created with a name different from `deploy`, pass it explicitly:

	```powershell
	.\upload.ps1 -RG ama-mro-playground -DeploymentName "<deployment-name>"
	```

7. Verify the main deployment outputs and application endpoints:

	```powershell
	az deployment sub show -n deploy --query properties.outputs
	```

	Check `frontendSpaFqdn`, `backendApiFqdn`, `mlWorkspaceName`, `postgresFqdn`, `engineeringSearchEndpoint`, and `engineeringAiServicesEndpoint` to confirm that the expected services were created.

### Application deployment from a development machine

Container Apps pulls private images from ACR with a dedicated user-assigned managed identity. The infrastructure deployment grants that identity `AcrPull`, integrates the Container Apps environment with the spoke VNet, and configures both apps in single revision mode.

The original PoC Container Apps environment was created without a custom VNet, and Azure doesn't allow changing an environment's network type. The first deployment of this configuration therefore creates parallel `cae-vnet-*`, `api-vnet-*`, and `web-vnet-*` resources. The original quickstart apps remain available until the new endpoints have been validated and can then be removed.

Run the infrastructure deployment once, or whenever its Bicep configuration changes. Always reuse the `resourceNameSeed` of the existing environment so resource names remain stable:

```powershell
az deployment sub what-if `
	--name deploy `
	--location francecentral `
	--template-file .\bicep\deploy.bicep `
	--parameters resourceNameSeed="<existing-seed>" `
							 deployerObjectId=$deployerObjectId `
							 deployerPrincipalName=$deployerPrincipalName `
							 postgresAdminPassword="<strong-password>"

az deployment sub create `
	--name deploy `
	--location francecentral `
	--template-file .\bicep\deploy.bicep `
	--parameters resourceNameSeed="<existing-seed>" `
							 deployerObjectId=$deployerObjectId `
							 deployerPrincipalName=$deployerPrincipalName `
							 postgresAdminPassword="<strong-password>"
```

Deploy the current API and SPA source from the repository root. ACR Tasks performs both Linux builds, pushes immutable images, and the script updates the two Container Apps sequentially with smoke tests:

```powershell
.\powershell\deploy-apps.ps1
```

The default tag combines the current Git commit and a UTC timestamp. Supply a tag when needed:

```powershell
.\powershell\deploy-apps.ps1 -Tag "manual-20260804-01"
```

Rollback both applications to an existing immutable tag without rebuilding:

```powershell
.\powershell\deploy-apps.ps1 -RollbackTag "<previous-tag>"
```

The script resolves registry and application names from the subscription deployment outputs. Pass `-DeploymentName` when the Bicep deployment isn't named `deploy`; `-AcrName`, `-BackendAppName`, and `-FrontendAppName` can override individual values explicitly.
