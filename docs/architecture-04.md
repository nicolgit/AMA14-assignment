# Architettura Applicativa — Piattaforma MRO Intelligence (v0.3, Azure-first) 

# Principi guida
- Azure PaaS first, IaaS solo dove serve: meno ops, integrazione nativa con Entra ID, Azure Monitor, Defender, Purview.
- Open formats sul dato a riposo (Delta su ADLS): portabilità futura, ma compute Azure-native.
- Managed Kafka via Event Hubs (Kafka surface) invece di Confluent self-managed: stesso protocollo, meno overhead.
- Stream processing → correlazione/alert (Azure Stream analytics o in alternativa Event Hub + Azurte Fucntions)
- raw storage su ADLS2 operational storage su cosmos o sql server (verificare la repatriation per cosmos)
- Landing Zone come baseline: Azure Landing Zones, hub-and-spoke, policy as code.


AI gateway centrale (APIM con policy AI) davanti a tutti gli LLM call: rate limit, content safety, audit, costi.
EU AI Act + GDPR by design: region EU, CMK, lineage, AI audit log immutabile, human-in-the-loop.



DataLake
* raw telemetry
* storico inventario
* dataset ML

CosmosBD/ SQL Server
* inventario operationale
* stato corrente



# 