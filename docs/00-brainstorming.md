# 00 — Brainstorming Presentazione HangarMind

> Obiettivo: consolidare idee, scaletta e storytelling per una presentazione di ~40 minuti  
> Audience: CIO, CFO, CISO, CTO  
> Lingua di lavoro: italiano (traduzione EN successiva)

---

## 1. L'audience: cosa interessa a chi?

| Ruolo | Domanda chiave | Angolo HangarMind |
|-------|---------------|-------------------|
| **CFO** | "Quanto ci costa oggi e quanto risparmiamo?" | AOG da 11h a <3h = riduzione costi diretti. 4.500 h/anno di doc → -55%. ROI tangibile, payback period |
| **CIO** | "Si integra con quello che abbiamo? È scalabile?" | Azure-native, hub-spoke, API Management, Fabric. Si inserisce nell'ecosistema esistente |
| **CTO** | "Funziona davvero? Che modelli usa? È affidabile?" | CNN-LSTM su C-MAPSS, margini di sicurezza statistici, human-in-the-loop, blue-green deployment |
| **CISO** | "È sicuro? Siamo compliant?" | Private endpoints, RBAC/PIM, GDPR, EU AI Act, EASA Part-145, NIS2, audit trail immutabili |

**Principio guida:** ogni slide deve rispondere almeno a due di queste domande. Se parla solo a uno dei quattro, è troppo di nicchia.

---

## 2. Struttura narrativa proposta (arco in 6 atti)

### Atto 1 — Incipit e contesto (minuti 0-7)

**Apertura (minuti 0-1)**

> "Buongiorno, sono **nicolgit**, Cloud Solution Architect.
> 
> Vi avverto: sono un tecnico, e tra poco vi mostrerò diagrammi e architetture.
> Ma prima di aprire il cofano, voglio partire dal motivo per cui lo stiamo facendo.
> 
> Il nostro MRO ha un problema strutturale: quando un motore si guasta senza preavviso, perdiamo in media 11 ore per rimettere l'aereo in linea. Il ricambio è nel magazzino sbagliato. La procedura è nella testa di un ingegnere che va in pensione. La documentazione EASA richiede ore di compilazione manuale.
> 
> La piattaforma che vi presento risolve questi tre problemi insieme.

**Il fattore umano (minuti 1-3)**

> "Per dare un volto al problema: Jean-Pierre ha 37 anni di esperienza sui motori CFM56. Tra 14 mesi va in pensione.
> Con lui se ne va il sapere di come diagnosticare un flutter anomalo che nessun manuale copre.
> Oggi quel sapere vive nella sua testa. Domani, dove vivrà?"

**I numeri del problema (minuti 3-5)**
- 340 aeromobili, 6 carrier, 12 hangar distribuiti in 5 paesi
- 11 ore di AOG medio per evento non programmato
- 4.500 ore/uomo all'anno per documentazione EASA
- 31% degli ingegneri senior in uscita nei prossimi 3 anni
- Formati dati OEM proprietari, nessun livello analitico unificato

**Ponte verso l'Atto 2 (minuti 5-7)**
- "Non è un problema tecnico. È un problema di business."
- Contestualizzazione: perché adesso, perché serve una piattaforma integrata (non cinque tool separati)

> **⚠️WARNING⚠️**: Non posso garantirvi oggi che l’AOG passerà automaticamente da 11 a meno di 3 ore. Quello è il target di business assegnato al programma, non un risultato già dimostrato. L’architettura rende possibile intervenire sulle cause del ritardo, ma il risultato dipende anche da ricambi, personale, processi e qualità dei dati.
> 
> **Quello che posso garantirvi è un percorso misurabile**: baseline iniziale, pilot controllato, KPI concordati e gate go/no-go. Prima estendiamo la soluzione a uno o due hangar, confrontiamo gli eventi trattati con casi omogenei e misuriamo AOG, disponibilità ricambi, tempo di compilazione e first-time-fix. Solo se il miglioramento è statisticamente e operativamente significativo procediamo allo scale-out. 

### Atto 2 — La visione: da reattivo a predittivo (minuti 7-11)

**Transizione dall'Atto 1:**
> "Vi ho mostrato il problema. Ora vi mostro il cambio di paradigma."

**Il framework concettuale: tre verbi**

| Oggi (reattivo) | Domani (predittivo) |
|---|---|
| **Rompi** → Ripara | **Prevedi** → Prepara → Preserva |
| Il guasto detta i tempi | Il dato anticipa il guasto |
| Il tecnico cerca il ricambio | Il ricambio aspetta il tecnico |
| L'ingegnere compila a mano | L'AI compila, l'ingegnere valida e firma |
| Il sapere è nelle teste | Il sapere è nella piattaforma |

> "Passiamo da un modello in cui il guasto detta i tempi a uno in cui il dato anticipa il guasto.
> Da un modello in cui il tecnico cerca il ricambio a uno in cui il ricambio aspetta il tecnico.
> Da un modello in cui l'esperto compila a mano a uno in cui l'AI propone e l'esperto valida."

**Le quattro leve di HangarMind (1 slide, schema visivo)**

Presentale come una catena causa-effetto, non come una lista:

```
Telemetria motore → [1. PREVEDI: RUL prediction]
                         ↓
                    [2. PREPARA: Spare parts optimization]
                         ↓
Evento manutenzione → [3. AUTOMATIZZA: EASA documentation]
                         ↓
                    [4. PRESERVA: Knowledge capture]
```

- **Leva 1 — Prevedi:** il motore ci dice quando sta per guastarsi (RUL)
- **Leva 2 — Prepara:** sapendo quando serve il ricambio, lo posizioniamo prima (spare optimization)
- **Leva 3 — Automatizza:** quando il tecnico interviene, la documentazione si genera (EASA copilot)
- **Leva 4 — Preserva:** ogni intervento cattura e codifica il sapere esperto (knowledge retention)

> "Non sono quattro progetti separati. Sono una pipeline: prevedere abilita preparare, che abilita automatizzare, che abilita preservare."

**I risultati attesi (1 slide, visual forte)**

| Metrica | Oggi | Obiettivo | Δ |
|---------|------|-----------|---|
| Tempo AOG per evento | 11 h | < 3 h | **−73%** |
| Disponibilità ricambi point-of-use | baseline | +34% | |
| Effort documentazione EASA | 4.500 h/anno | ~2.000 h/anno | **−55%** |
| First-time-fix rate | 71% | 89% | **+18pp** |

> "Questi non sono target aspirazionali. Sono i numeri che l'architettura che vi mostro tra un minuto è disegnata per raggiungere."

**Chiusura Atto 2 — ponte verso l'architettura:**
> "Ora sapete COSA vogliamo ottenere e PERCHÉ. Vi mostro il COME: l'architettura della piattaforma."

### Atto 3 — L'architettura della soluzione (minuti 11-20) ⬅ CUORE CSA
Questo è il momento in cui il CSA "apre il cofano" e mostra come la soluzione sta in piedi.

I pillar sono allineati al **Well-Architected Framework (WAF)** di Microsoft.

**3A — Vista d'insieme (1 diagramma architetturale, 2-3 minuti)**
- Diagramma end-to-end: edge/IoT → ingestion → data platform → AI/ML → app layer → utenti
- Landing Zone: hub-spoke networking, subscription topology
- Flusso dati: dalla telemetria OEM fino alla dashboard e alla task card

> "Prima di entrare nei dettagli, guardiamo l'insieme. Questo diagramma racconta un solo flusso, da sinistra a destra: la telemetria dei motori arriva dagli aeromobili in flotta, viene ingerita in modo sicuro dentro la nostra landing zone, atterra nella data platform dove viene normalizzata, e da lì i modelli AI/ML calcolano il Remaining Useful Life. Il risultato non resta un numero in un database: diventa un'azione concreta nell'app layer — una dashboard per il manutentore e una task card conforme EASA. Tre cose che voglio farvi notare. Primo: è tutto dentro una landing zone hub-spoke, quindi ogni componente è isolato in rete e nessun dato è esposto pubblicamente. Secondo: ogni box che vedete è un servizio Azure managed, non un server che dobbiamo patchare noi. Terzo: questo non è uno schema teorico, è ciò che è già deployato via Bicep. Tenete a mente questo flusso, perché nei prossimi minuti lo attraverso pillar per pillar — sicurezza, affidabilità, costi — per mostrarvi che ogni scelta è giustificata, non casuale."

**3B — Pillar WAF: Security (3-4 minuti)**
- Network isolation: hub-spoke, private endpoints, nessun public exposure
- Identity: Entra ID, PIM, Managed Identity, RBAC fine-grained
- Data protection: encryption at rest (CMK) + in transit (TLS 1.3)
- Secrets: Key Vault, no credentials in code
- Monitoring: Sentinel, Defender for Cloud, threat detection

> "Partiamo dalla sicurezza, perché in un'organizzazione aviation è la prima domanda che vi farà il vostro CISO — e non è una domanda IT, è una domanda di safety e di reputazione. Qui non parliamo solo di dati: parliamo della telemetria dei motori della flotta e della documentazione di manutenzione che deve reggere a un audit EASA. Se questi dati vengono manomessi o esfiltrati, il rischio non è una multa: è un aeromobile che vola con una decisione manutentiva basata su dati compromessi. Per questo la security qui è disegnata dall'inizio, non aggiunta dopo. La risposta breve è: questa piattaforma è chiusa per costruzione. Vi porto attraverso cinque livelli.
>
> Primo, la rete. Tutto vive in una topologia hub-spoke con private endpoint: i servizi non hanno un indirizzo pubblico, i dati non transitano mai su internet e il traffico tra i componenti resta dentro la nostra rete privata. In pratica non c'è una porta esposta che un attaccante possa bussare dall'esterno. Il traffico verso l'esterno è filtrato e ispezionato centralmente nell'hub.
>
> Secondo, l'identità. Non ci sono password o stringhe di connessione nei servizi: ogni componente si autentica con Managed Identity ed Entra ID. Gli accessi amministrativi sono just-in-time via PIM — nessuno ha privilegi permanenti, li richiede quando servono e scadono da soli. E l'autorizzazione è RBAC granulare: un tecnico in linea vede i dati della sua flotta, non quelli di un altro operatore, e non può toccare la pipeline di training del modello. Least privilege applicato davvero, non sulla carta.
>
> Terzo, i dati. Cifrati a riposo con chiavi gestite da noi in Key Vault e in transito con TLS 1.3, end-to-end: vale sia per la telemetria sia per le task card EASA. Questo ci permette anche di rispettare la data residency — i dati restano nella region europea che scegliamo, un requisito non negoziabile in questo contesto regolatorio.
>
> Quarto, i segreti. Centralizzati in Key Vault, con rotazione e audit di ogni accesso: zero credenziali nel codice, zero segreti nei file di configurazione. Se domani va ruotata una chiave, si fa in un punto solo senza toccare le applicazioni.
>
> Quinto, il monitoraggio. Defender for Cloud ci dà la postura di sicurezza continua e le raccomandazioni di hardening; Sentinel correla i log e fa threat detection in tempo reale. E soprattutto abbiamo una traccia di audit completa e immutabile: chi ha fatto cosa, quando, su quale dato — esattamente ciò che un ispettore EASA o un auditor NIS2 vi chiederà di dimostrare.
>
> Il punto che voglio lasciarvi è questo: nessuno di questi controlli è un add-on opzionale, sono tutti codificati in Bicep e ridistribuibili in modo identico ad ogni ambiente. La sicurezza non dipende da qualcuno che si ricorda di configurarla. È esattamente il motivo per cui il vostro CISO può firmare l'approvazione senza chiedere deroghe — e per cui potete difendere questa piattaforma davanti a un auditor invece di temerlo."

**3C — Pillar WAF: Reliability (2-3 minuti)**
- **Baseline già implementata:** Container Apps con autoscaling, ADLS Gen2 in ZRS, soft delete a 30 giorni, backup PostgreSQL a 7 giorni, monitoraggio centralizzato
- **Hardening per la produzione:** almeno 2 repliche applicative distribuite su Availability Zone, health probe, PostgreSQL zone-redundant HA, deployment ML blue-green con rollback
- **Disaster Recovery regionale:** seconda region in warm standby, dati replicati, failover governato e testato; target proposti **RPO ≤ 15 minuti / RTO ≤ 60 minuti**
- **Elasticità:** da 340 aeromobili oggi a 500+ domani aumentando repliche e capacità, senza ridisegnare la piattaforma
- → Messaggio: "non confondiamo alta disponibilità e disaster recovery: progettiamo, misuriamo e testiamo entrambi"

> "Dopo aver chiuso le porte con la security, la domanda successiva del CIO è inevitabile: cosa succede quando qualcosa si rompe? La risposta non è 'Azure non cade mai'. La risposta seria è che assumiamo il guasto e progettiamo il servizio perché continui a funzionare o venga ripristinato entro obiettivi misurabili.
>
> Partiamo dal livello applicativo. Backend e frontend girano su Container Apps e scalano automaticamente in base al carico. Nel PoC abbiamo scelto intenzionalmente una configurazione economica, da zero a due repliche. Per la produzione il profilo cambia: almeno due repliche sempre attive, distribuzione tra Availability Zone e health probe che rimuovono dal traffico un'istanza non sana. Se un container si arresta, la piattaforma lo sostituisce; se il carico cresce, aggiunge capacità senza intervento manuale. È così che passiamo da 340 a oltre 500 aeromobili senza una nuova architettura.
>
> Secondo livello: dati e modello. Il Data Lake usa già storage ZRS, quindi mantiene copie sincrone in zone diverse della stessa region, e il soft delete a 30 giorni protegge dalle cancellazioni accidentali. PostgreSQL oggi ha backup a sette giorni ma, coerentemente con lo stato PoC, non ha ancora high availability né backup geografico: prima del go-live abilitiamo HA zone-redundant e geo-backup. Per il modello RUL adottiamo deployment blue-green: la nuova versione riceve prima traffico controllato, viene confrontata con quella corrente e, se degrada accuratezza o latenza, il rollback è immediato. Questo traffic split è un gate di produzione, non una capacità che dichiariamo già completata.
>
> Terzo livello: la perdita di un'intera region. ZRS protegge dal guasto di una zona, non da quello regionale. Per questo il target production prevede una seconda region europea in warm standby, infrastruttura ricreabile dallo stesso Bicep, replica dei dati e una procedura di failover provata periodicamente. Proponiamo due impegni da validare con il business: RPO entro 15 minuti, cioè al massimo 15 minuti di dati da recuperare, e RTO entro 60 minuti, cioè servizio critico ripristinato entro un'ora. Non basta scriverli in una slide: vanno verificati con esercitazioni di disaster recovery e misurati dall'osservabilità centralizzata.
>
> Il punto è questo: il PoC dimostra il flusso end-to-end; il production hardening trasforma quel flusso in un servizio affidabile. Non promettiamo che nulla si guasti. Dimostriamo che un guasto di istanza, zona o region ha una risposta progettata, automatizzabile e testabile."

**3D — Pillar WAF: Cost Optimization (2-3 minuti)**
- **Baseline già implementata:** ML serverless rilasciato a fine job, Container Apps da 0 a 2 repliche, PostgreSQL Burstable, capacità AI esplicite e tagging per workload/ambiente/cost center
- **Ottimizzazione production:** pay-per-use per carichi variabili; reservation o savings plan solo sulla baseline stabile; Spot per training interrompibile; lifecycle hot/cool/archive per lo storico
- **FinOps:** budget e anomaly alert per ambiente, forecast mensile, owner per ogni risorsa e dashboard di costo unitario
- **Unit economics:** costo per aeromobile, predizione RUL e task card; confronto con ore AOG, effort documentale e logistica ricambi evitati
- **Gate finanziario:** il payback viene dichiarato solo dopo aver validato volumi, costo orario AOG e saving realmente attribuibile alla piattaforma
- → Messaggio: "ottimizziamo il costo per risultato operativo, non il costo della singola risorsa"

> "Una piattaforma può essere sicura e affidabile, ma se il costo non è prevedibile il CFO la fermerà prima della produzione. La domanda quindi è: quanto costa produrre un risultato utile, non quanto costa tenere accesa una risorsa Azure?
>
> Nel PoC abbiamo già eliminato lo spreco più evidente. Il training RUL usa Azure ML serverless: la macchina viene creata per il job e rilasciata al termine. Container Apps scala da zero a due repliche e PostgreSQL usa una SKU Burstable. Anche la capacità dei modelli generativi e degli embedding è dichiarata esplicitamente. Non paghiamo quindi cluster inattivi o risorse prive di un limite progettuale.
>
> In produzione non useremo però la stessa leva ovunque. Training e batch restano pay-per-use e possono usare Spot se il job è riprendibile. Sulla baseline stabile valuteremo reservation o savings plan, ma solo dopo aver misurato l'utilizzo. Per i dati: hot per il percorso operativo, cool per lo storico consultato raramente, archive per ciò che conserviamo per obbligo. Spot e lifecycle policy non sono ancora nel PoC: sono gate del production hardening.
>
> Poi c'è la governance. Le risorse sono già etichettate per workload, ambiente, owner e cost center; useremo questi tag per budget, anomaly alert e forecast. Al comitato non porteremo soltanto la fattura Azure, ma euro per aeromobile, predizione RUL e task card, collegati a ore AOG evitate, effort documentale e trasferimenti urgenti ridotti.
>
> È qui che il TCO diventa una decisione. Confrontiamo investimento, cloud, operation e change management con il valore dei target: AOG da 11 a meno di 3 ore, documentazione meno 55% e disponibilità ricambi più 34%. Non inventiamo una percentuale di ROI: validiamo eventi annui, costo orario AOG e saving attribuibile a HangarMind; poi fissiamo payback e soglia go/no-go.
>
> Il CFO non finanzia così un buco nero IT: riceve costi attribuibili, limiti e unit economics confrontabili con il problema. La piattaforma cresce soltanto quando cresce il valore prodotto."

**3E — Pillar WAF: Operational Excellence (1-2 minuti)**
- **Baseline già implementata:** infrastruttura Bicep modulare e versionabile, health endpoint applicativo, Application Insights, Log Analytics e diagnostica Azure ML centralizzata
- **Delivery production:** pipeline CI/CD con validazione Bicep, test, ambienti separati, approvazione e rollback; blue-green per applicazione e modello
- **Osservabilità operativa:** SLI/SLO per disponibilità, latenza, errori e qualità ML; alert azionabili, dashboard per ruolo e correlation ID end-to-end
- **Incident management:** ownership, severity, escalation, runbook e post-incident review; esercitazioni periodiche su rollback e DR
- **Gate Day 2:** pipeline, alert rule, workbook e runbook non sono ancora codificati nel PoC e devono essere verificati prima del go-live
- → Messaggio: "Operational Excellence significa rendere il comportamento corretto ripetibile, osservabile e migliorabile"

> "Fin qui abbiamo visto come la piattaforma resiste ai guasti e controlla i costi. Ma il vero test inizia il giorno dopo il go-live: chi la distribuisce, chi si accorge di un degrado e chi sa cosa fare alle tre del mattino?
>
> La baseline c'è già. L'infrastruttura è descritta in moduli Bicep, quindi è versionabile e ripetibile. L'API espone un health endpoint; applicazione e workspace ML inviano log e metriche ad Application Insights e Log Analytics.
>
> Il production hardening completa però il ciclo operativo. Ogni modifica deve attraversare una pipeline: validazione del Bicep, test automatici, ambiente di staging, approvazione e rollback. Applicazione e modello vengono rilasciati in blue-green, così una versione degradata non diventa un incidente esteso. Pipeline e traffic split non sono ancora implementati nel PoC: sono gate obbligatori prima del go-live.
>
> Poi trasformiamo la telemetria in decisioni. Definiamo SLO per disponibilità, latenza ed errori, ma anche per qualità del modello, drift e override umano. Gli alert devono indicare impatto, owner e prima azione; per gli scenari critici servono runbook, livelli di severità, escalation e post-incident review. Oggi abbiamo le fondamenta di osservabilità, non ancora questo modello operativo completo.
>
> Il risultato non è promettere che serviranno poche persone. È dare al team procedure automatizzate e segnali utili, affinché deployment e incidenti siano ripetibili, misurabili e migliorino dopo ogni evento. Questa è l'Operational Excellence: non soltanto costruire bene la piattaforma, ma saperla gestire dal Day 2."

**3F — Pillar WAF: Performance Efficiency (1 minuto)**
- Latenza inferenza RUL: target <200ms per scoring online
- Sizing: right-sizing compute per workload (training GPU vs. inference CPU)
- Auto-scale: Container Apps scale-to-zero, burst per picchi di manutenzione
- Caching e ottimizzazione query: AI Search semantic ranking, PostgreSQL indexing

> questo è il motivo per cui il tecnico non aspetta il sistema

### Atto 4 — I tre use case AI in azione (minuti 20-28)
Ora che l'architettura è chiara, i tre use case diventano "prove" che la piattaforma funziona.
Pattern per ciascuno: **problema → dove vive nell'architettura → DEMO → beneficio misurato**
Enfasi costante: "L'AI propone, l'uomo decide e firma"

**AI-01: Il motore parla (minuti 20-23)**
- Problema: guasto non previsto → 11h AOG
- Dove vive: IoT Hub → Stream Analytics → ML endpoint (CNN-LSTM) → API → dashboard
- 🎬 **Demo (~1 min):** screenshot o live della dashboard con il semaforo RUL
  - Mostra un motore che passa da verde a giallo
  - Evidenzia: RUL residuo, margine di sicurezza, livello di urgenza
  - Piano B: screenshot statico con annotazioni
- Beneficio: AOG da 11h a <3h, manutenzione programmata invece che reattiva

**AI-02: Il ricambio giusto, al posto giusto (minuti 23-25)**
- Problema: ricambio nel magazzino sbagliato, cannibalizzazione componenti
- Dove vive: PostgreSQL + ML scoring → optimization engine → Field Service integration
- 🎬 **Demo (~30s):** mappa d'Europa con i 12 hangar
  - Mostra scorte, flussi di trasferimento suggeriti, scoring di urgenza
  - Piano B: slide con mappa statica + frecce di flusso
- Beneficio: disponibilità ricambi +34%, fine cannibalizzazione

**AI-03: L'ingegnere che detta (minuti 25-28) ⬅ MOMENTO WOW**
- Problema: task card compilate a mano, 4.500h/anno, errori, nessun riferimento normativo
- Dove vive: Speech Services → Azure OpenAI → AI Search (RAG, private link) → app review → firma
- 🎬 **Demo (~1.5 min):** il pezzo forte della presentazione
  - Opzione A (ideale): video registrato di voce tecnico → task card che si compila live
  - Opzione B: before/after side-by-side (task card manuale vs. generata con citazioni EASA)
  - Opzione C (fallback): screenshot annotato del flusso Speech → RAG → output
  - In tutti i casi: evidenziare le citazioni AMM/SRM, l'effectivity check, il pulsante di firma umana
- Beneficio: effort doc -55%, first-time-fix 71%→89%, knowledge retention di Jean-Pierre

### Atto 5 — Compliance normativa (minuti 28-32)
Separato dalla security tecnica (già coperta nell'Atto 3B), qui si parla di REGOLAMENTI:

- Mappa normativa: GDPR + EU AI Act + EASA Part-145 + NIS2 + EU Data Act
- Come l'architettura risponde a ciascuno (linkare ai pillar dell'Atto 3)
- Shared responsibility: cosa fa Azure, cosa facciamo noi, cosa fa il cliente MRO
- EU AI Act: classificazione high-risk, obblighi specifici, timeline 2027
- Checklist governance: dal design al go-live (già implementata)
- → Messaggio: "la compliance non è un add-on, è embedded nel design"

### Atto 6 — Il ritorno e la call-to-action (minuti 32-40)
- Ritorno narrativo: "Torniamo all'Hangar 7, sei mesi dopo..."
- I numeri del cambiamento (ripetizione KPI con before/after enfatizzato)
- Roadmap: cosa abbiamo fatto, cosa manca, prossimi passi
- Il costo del non fare nulla (risk framing per il CFO)
- Total Cost of Ownership: investimento vs. risparmio annualizzato
- Call-to-action: approvazione budget, timeline, team

---

## 3. Principi di storytelling da seguire

1. **Regola del "So what?"** — Ogni slide deve superare il test "e quindi?" Se non porta a un'azione o decisione, via.

2. **Numeri con contesto** — Mai un numero solo. Sempre: prima → dopo, o confronto con benchmark industry. "11 ore di AOG" non dice nulla se non dici che la media IATA è 6.

3. **La piramide di Minto** — Parti dalla conclusione ("HangarMind riduce i costi del X% e ci rende compliant"), poi giustifica con i pillar, poi dettaglia. Non arrivare alla conclusione alla fine.

4. **Show, don't tell** — Almeno 2 momenti "wow": una demo live, uno screenshot reale, un dato controintuitivo. I C-level vedono 50 presentazioni al mese, devi differenziarti.


5. **L'analogia del ponte** — Ogni volta che passi da un atto all'altro, usa una frase-ponte che lega il vecchio al nuovo. Es: "Ora sappiamo che il motore sta per guastarsi. Ma il pezzo di ricambio dov'è?" → transizione naturale da AI-01 a AI-02.

6. **Chiudi il cerchio** — La storia dell'Hangar 7 torna nell'atto 5. Il pubblico ricorda l'inizio e la fine, raramente il mezzo.

---

## 4. Idee per momenti "wow" / differenzianti

- **Il semaforo RUL live** — Mostra un motore che passa da verde a giallo con i dati che scorrono. Anche simulato, è potente.
- **La voce del tecnico** — Fai partire un audio (anche registrato) di un tecnico che detta una finding, e mostra la task card che si compila in tempo reale. È il momento più cinematografico.
- **Il before/after della task card** — Due colonne: a sinistra una task card compilata a mano (lunga, imprecisa, senza riferimenti). A destra quella generata dall'AI (strutturata, con citazioni EASA, con effectivity). Visivamente devastante.
- **La mappa dei 12 hangar** — Una mappa d'Europa con i 12 hangar, le scorte, i flussi di trasferimento. Mostra il problema della frammentazione e come il sistema lo risolve.
- **Il "costo di Jean-Pierre"** — Calcola quanto costa non codificare il sapere: costo di ri-training × numero di senior in uscita × tasso di errore dei junior. Numero grande, impatto emotivo.

---

## 5. Rischi di comunicazione da evitare

| Rischio | Mitigazione |
|---------|-------------|
| Troppo tecnico per il CFO | Tenere i dettagli ML nell'appendice. Nel main deck: input → output → beneficio |
| Troppo vago per il CTO | Avere slide di backup con architettura, stack, modelli. Pronte per le domande |
| Sottovalutare il CISO | Dedicare tempo esplicito a compliance e sicurezza. Non è un afterthought |
| Presentazione troppo lunga | 40 minuti sono 25-28 slide MAX. Meno è meglio. Prevedere 10 min di Q&A |
| Demo che fallisce | Avere sempre screenshot/video di backup. Mai demo live senza piano B |
| Nessuna call-to-action | Chiudere SEMPRE con: "Vi chiediamo X, entro Y, per ottenere Z" |

---

## 6. Temi aperti / da decidere

- [ ] Quanto tempo dedicare alla demo vs. storytelling? (proposta: 60% storia, 40% demo)
- [ ] Mostriamo l'architettura Azure in dettaglio o solo a blocchi? (proposta: blocchi nel main, dettaglio in appendice)
- [ ] Inseriamo un confronto competitivo? (rischio: distrae; vantaggio: posiziona)
- [ ] Includiamo un TCO/ROI quantitativo? (il CFO lo vuole, ma i numeri devono essere difendibili)
- [ ] Lingua delle slide finali: EN o misto? (proposta: slide in EN, speaker notes in IT, presentazione orale in IT)
- [ ] Quante persone presentano? Se sono più di una, servono transizioni pulite

---

## 7. Scaletta timing (bozza)

| Minuti | Atto | Sezione | Slide stimate | Chi parla a... |
|--------|------|---------|---------------|----------------|
| 0-1 | 1 | Apertura — "sono un tecnico, ma..." | 1 | Tutti |
| 1-3 | 1 | Il fattore umano — Jean-Pierre | 1 | CTO, CFO |
| 3-5 | 1 | I numeri del problema | 2 | CFO, CIO |
| 5-7 | 1 | Ponte: "non è un problema tecnico, è di business" | 1 | Tutti |
| 7-9 | 2 | Framework: da reattivo a predittivo + le 4 leve | 2 | Tutti |
| 9-11 | 2 | KPI before/after | 1 | CFO |
| 11-13 | 3 | 3A: Architettura end-to-end (diagramma) | 1-2 | CIO, CTO |
| 13-15 | 3 | 3B: WAF Security | 2 | CISO, CTO |
| 15-16 | 3 | 3C: WAF Reliability | 1 | CIO, CTO |
| 16-18 | 3 | 3D: WAF Cost Optimization | 1-2 | CFO, CIO |
| 18-19 | 3 | 3E: WAF Operational Excellence | 1 | CIO, CTO |
| 19-20 | 3 | 3F: WAF Performance Efficiency | 1 | CTO |
| 20-23 | 4 | AI-01: RUL + 🎬 demo semaforo (~1 min) | 2-3 | CTO |
| 23-25 | 4 | AI-02: Spare parts + 🎬 demo mappa (~30s) | 2 | CFO, CIO |
| 25-28 | 4 | AI-03: Copilot + 🎬 demo voce→task card (~1.5 min) | 2-3 | CTO, CFO |
| 28-32 | 5 | Compliance normativa | 3 | CISO, CIO |
| 32-35 | 6 | Ritorno narrativo + KPI | 2 | Tutti |
| 35-38 | 6 | Roadmap + TCO | 2 | CFO, CIO |
| 38-40 | 6 | Call-to-action + chiusura | 1 | Tutti |
| | | **Totale** | **~28 slide** | |

---

*Prossimo passo: validare questa struttura, poi passare ai contenuti tecnici slide per slide.*
