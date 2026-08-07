# Development Environment Monthly Cost

This estimate is based on the Azure resources defined in the Bicep deployment, the Azure Retail Prices for France Central in EUR as of August 7, 2026, and 730 operating hours per month. Quantity and SKU are combined into one column to keep the table to three columns.

| Azure service | Instances and SKU | Estimated monthly cost |
|---|---|---:|
| Azure AI Search | 1 x Standard S1 | EUR 215.28 |
| Azure DNS Private Resolver | 1 inbound endpoint + 1 outbound endpoint | EUR 315.93 |
| VPN Gateway | 1 x VpnGw1AZ | EUR 134.54 |
| Azure Database for PostgreSQL Flexible Server | 1 x Burstable B1ms + 32 GB storage | EUR 15.93 |
| Azure Container Registry | 1 x Standard | EUR 17.78 |
| Private Endpoint | 6 x Standard | Approximately EUR 38.54 |
| Public IP Address | 1 x Standard static IPv4 | EUR 3.21 |
| Private DNS Zone | 7 x Private | EUR 3.07 + consumption-based queries |
| Azure Container Apps | 2 apps, 0-2 replicas, Consumption plan | consumption |
| Azure OpenAI chat model | 1 x DataZoneStandard, 30K TPM | consumption |
| Azure OpenAI embedding model | 1 x Standard, 10K TPM | consumption |
| Azure AI Speech | 1 x S0 | consumption |
| Log Analytics | 1 x PerGB2018, 30-day retention | consumption |
| Application Insights | 1 x workspace-based | consumption |
| Azure Data Lake Storage | 1 x Standard ZRS, Hot tier | consumption |
| Azure Machine Learning workspace storage | 1 x Standard LRS, Hot tier | consumption |
| Azure Key Vault | 1 x Standard | consumption |
| Azure Machine Learning | 1 workspace + 1 online endpoint without a compute deployment | EUR 0.00 until compute is deployed |
| Virtual Network | 1 VNet, 6 subnets | EUR 0.00 |
| Managed Identities | 2 user-assigned identities | EUR 0.00 |
| Resource Group and RBAC | 1 resource group + role assignments | EUR 0.00 |

The estimated fixed monthly cost is **approximately EUR 744.28**, excluding usage-based charges, data transfer, DNS queries, AI tokens, telemetry ingestion, storage capacity, storage operations, backup overages, and taxes. Actual costs may vary according to Azure agreement discounts, reservations, credits, exchange rates, and service usage.
