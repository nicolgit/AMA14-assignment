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

**3B — Pillar WAF: Security (3-4 minuti)**
- Network isolation: hub-spoke, private endpoints, nessun public exposure
- Identity: Entra ID, PIM, Managed Identity, RBAC fine-grained
- Data protection: encryption at rest (CMK) + in transit (TLS 1.3)
- Secrets: Key Vault, no credentials in code
- Monitoring: Sentinel, Defender for Cloud, threat detection
- → Diagramma: "nessun dato esce dalla rete privata"

**3C — Pillar WAF: Reliability (2-3 minuti)**
- Compute: Container Apps (auto-scale), Azure ML managed endpoints (blue-green)
- Data: ADLS Gen2 + Delta Lake (petabyte-ready), Fabric per analytics
- Resilienza: multi-AZ, DR strategy, RPO/RTO targets
- Elasticità: da 340 aeromobili oggi a 500+ domani senza re-architecture
- → Messaggio: "la piattaforma scala con il business, non è un PoC"

**3D — Pillar WAF: Cost Optimization (2-3 minuti)**
- Modello di costo: pay-per-use vs. reserved (ML compute, storage tiers)
- Leve di ottimizzazione: spot instances per training, hot/cool/archive per i dati storici
- TCO confronto: costo piattaforma vs. costo attuale AOG + doc + ricambi sbagliati
- Governance costi: budget alerts, cost anomaly detection, tagging strategy
- → Messaggio: "non è un costo IT, è un investimento con payback misurabile"

**3E — Pillar WAF: Operational Excellence (1-2 minuti)**
- Infrastructure as Code: tutto il deploy è Bicep, ripetibile, versionato
- CI/CD: pipeline di deploy automatizzate, blue-green per ML endpoints
- Incident management: runbook operativi, alerting, escalation
- Observability: Application Insights, Log Analytics, workbook operativi
- → Messaggio: "non è solo costruita bene, è gestibile dal Day 2"

**3F — Pillar WAF: Performance Efficiency (1 minuto)**
- Latenza inferenza RUL: target <200ms per scoring online
- Sizing: right-sizing compute per workload (training GPU vs. inference CPU)
- Auto-scale: Container Apps scale-to-zero, burst per picchi di manutenzione
- Caching e ottimizzazione query: AI Search semantic ranking, PostgreSQL indexing

### Atto 4 — I tre use case AI in azione (minuti 20-28)
Ora che l'architettura è chiara, i tre use case diventano "prove" che la piattaforma funziona.

- **AI-01: Il motore parla** — telemetria → CNN-LSTM → semaforo urgenza → decisione umana
  - Dove vive nell'architettura: IoT Hub → Stream Analytics → ML endpoint → API → dashboard
- **AI-02: Il ricambio giusto, al posto giusto** — urgency scoring → sourcing ottimale → Dynamics 365
  - Dove vive: PostgreSQL + ML scoring → optimization engine → Field Service integration
- **AI-03: L'ingegnere che detta** — voce → Speech → OpenAI + RAG → task card → firma umana
  - Dove vive: Speech Services → Azure OpenAI → AI Search (private link) → app review

Per ciascuno: 2-3 minuti, pattern "problema → componenti Azure → output → beneficio misurato"
Enfasi costante: "L'AI propone, l'uomo decide e firma"

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

| Minuti | Sezione | Slide stimate | Chi parla a... |
|--------|---------|---------------|----------------|
| 0-2 | Cold open — l'aereo fermo | 1-2 | Tutti |
| 2-4 | Il fattore umano — Jean-Pierre | 1 | CTO, CFO |
| 4-7 | I numeri del problema | 2-3 | CFO, CIO |
| 7-9 | La visione: da reattivo a predittivo | 2 | Tutti |
| 9-11 | KPI before/after | 1 | CFO |
| 11-13 | Architettura end-to-end (diagramma) | 1-2 | CIO, CTO |
| 13-16 | Pillar: Security & Zero-Trust | 2-3 | CISO, CTO |
| 16-18 | Pillar: Scalabilità & Reliability | 2 | CIO, CTO |
| 18-20 | Pillar: Cost & FinOps | 1-2 | CFO, CIO |
| 20-23 | AI-01: Predizione RUL | 2-3 | CTO |
| 23-25 | AI-02: Ottimizzazione ricambi | 2 | CFO, CIO |
| 25-28 | AI-03: Engineering Copilot | 2-3 | CTO, CFO |
| 28-32 | Compliance normativa | 3 | CISO, CIO |
| 32-35 | Ritorno narrativo + KPI | 2 | Tutti |
| 35-38 | Roadmap + TCO | 2 | CFO, CIO |
| 38-40 | Call-to-action + chiusura | 1 | Tutti |
| | **Totale** | **~27 slide** | |

---

*Prossimo passo: validare questa struttura, poi passare ai contenuti tecnici slide per slide.*
