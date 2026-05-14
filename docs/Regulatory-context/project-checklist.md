Azioni concrete da pianificare nel progetto, ordinate per priorità normativa. Le voci in rosso sono obblighi non delegabili ad Azure.

## Prima dell'avvio (design phase)

- Selezionare region Azure EU (West/North Europe) e abilitare geo-redundancy — prerequisito GDPR e EASA **Critico**
- Firmare il Microsoft Data Processing Agreement (DPA) — già disponibile online, copre GDPR art. 28 **Critico**
- Includere Azure nel perimetro ISMS (EASA Cyber UE 2023/203) e documentare i controlli ereditati vs propri **Critico**
- Eseguire Data Residency check su tutti i servizi Azure usati (AI Foundry, Cognitive Services, ecc.) **Alto**
- Progettare export dati in formato aperto e documentare exit strategy (EU Data Act art. 23-31) **Alto**
- Inserire Azure nel registro fornitori critici NIS2 con valutazione del rischio di concentrazione **Alto**

## Durante lo sviluppo (build phase)
- Configurare MFA + Conditional Access + PIM su Microsoft Entra ID — richiesto EASA ISMS e NIS2 **Critico**
- Implementare logging centralizzato (Azure Monitor + Sentinel) per audit trail EASA Part-145 e incident detection NIS2 **Critico**
- Definire politica di backup e retention allineata a EASA Part-145 (record keeping 5 anni minimo) **Alto**
- Eseguire DPIA (GDPR) per i trattamenti ad alto rischio su cloud (dati tecnici personali, health monitoring) **Alto**
- Configurare Microsoft Purview per data classification e DLP — supporta conformità GDPR e EASA **Alto**
- Utilizzare Azure Policy + Defender for Cloud per continuous compliance monitoring (ISO 27001, NIS2 benchmark)

## Prima del go-live (pre-production)
- Penetration test sulla soluzione Azure (non coperto dalla certificazione Azure stessa) — richiesto NIS2 e EASA ISMS **Critico**
- Testare il Business Continuity / Disaster Recovery plan (outage Azure scenario) — NIS2 resilience requirement **Critico**
- Validare la soluzione con il Quality Manager EASA Part-145 e documentarla nel CAME come sistema informatico approvato **Alto**
- Predisporre procedura di notifica incidenti cyber (NIS2: 24h early warning, 72h notifica, 1 mese report finale) **Medio**