# 00 — Brainstorming Presentazione HangarMind

> Obiettivo: consolidare idee, scaletta e storytelling per una presentazione di ~40 minuti  
> Audience: CIO, CFO, CISO, CTO  
> Lingua di lavoro: italiano (traduzione EN successiva)

---

## 1. Il problema dello storytelling: come aprire?

### Opzione A — "L'aereo fermo" (cold open narrativa)

Apri con un fatto concreto, quasi cinematografico:

> "Sono le 06:14, Hangar 7 a Toulouse. Un A320neo è fermo da 9 ore per un guasto al sistema bleed-air.
> Il componente di ricambio esiste — ma è nel magazzino di Amburgo.
> Il tecnico senior che conosce la procedura è in pensione da tre mesi.
> La task card EASA è incompleta.
> Sei passeggeri hanno perso la coincidenza, la compagnia ha un AOG da 42.000 €, e tutto poteva essere evitato."

Poi giri: **"Questo scenario si ripete 340 volte l'anno nella nostra flotta. HangarMind esiste per impedirlo."**

**Perché funziona:** mette i C-level dentro il problema, crea urgenza, è memorabile. Non è un elenco di feature — è una storia.

### Opzione B — "I cinque segnali ignorati" (pattern recognition)

Apri mostrando che il problema non è un singolo guasto ma un pattern sistemico:

1. Il motore mandava segnali da 80 cicli — nessuno li ha correlati
2. Il ricambio c'era, ma nel magazzino sbagliato
3. L'ingegnere sapeva come fare, ma la procedura non era codificata
4. La task card è stata compilata a mano, 3 ore dopo
5. Il report EASA è stato rifatto due volte perché mancavano i riferimenti normativi

Poi: **"Cinque fallimenti indipendenti che producono un unico risultato: l'aereo resta a terra. HangarMind interviene su tutti e cinque."**

**Perché funziona:** mostra la natura multi-dimensionale del problema, giustifica una soluzione integrata (non cinque tool separati).

### Opzione C — "Il pensionamento" (human angle)

> "Jean-Pierre ha 37 anni di esperienza sui motori CFM56. Tra 14 mesi va in pensione.
> Con lui se ne va il 'sapere' di come diagnosticare un flutter anomalo che nessun manuale copre.
> Oggi quel sapere vive nella sua testa. Domani, dove vivrà?"

**Perché funziona:** il knowledge loss è il tema più emotivo; colpisce il CTO (competenze), il CIO (rischio operativo), il CFO (costo di riaddestramento).

### Raccomandazione

**Combinare A + C:** apri con "l'aereo fermo" (2 minuti di cold open), poi introduci il fattore umano di Jean-Pierre. In 4 minuti hai catturato l'attenzione e hai giustificato sia la componente predittiva sia quella di knowledge management.

---

## 2. L'audience: cosa interessa a chi?

| Ruolo | Domanda chiave | Angolo HangarMind |
|-------|---------------|-------------------|
| **CFO** | "Quanto ci costa oggi e quanto risparmiamo?" | AOG da 11h a <3h = riduzione costi diretti. 4.500 h/anno di doc → -55%. ROI tangibile, payback period |
| **CIO** | "Si integra con quello che abbiamo? È scalabile?" | Azure-native, hub-spoke, API Management, Fabric. Si inserisce nell'ecosistema esistente |
| **CTO** | "Funziona davvero? Che modelli usa? È affidabile?" | CNN-LSTM su C-MAPSS, margini di sicurezza statistici, human-in-the-loop, blue-green deployment |
| **CISO** | "È sicuro? Siamo compliant?" | Private endpoints, RBAC/PIM, GDPR, EU AI Act, EASA Part-145, NIS2, audit trail immutabili |

**Principio guida:** ogni slide deve rispondere almeno a due di queste domande. Se parla solo a uno dei quattro, è troppo di nicchia.

---

## 3. Struttura narrativa proposta (arco in 6 atti)

### Atto 1 — Il contesto e il dolore (minuti 0-7)
- Cold open: l'aereo fermo (Opzione A)
- I numeri del problema: 340 aeromobili, 6 carrier, 12 hangar, 11h AOG, 4500h doc, 31% pensionamenti
- "Non è un problema tecnico. È un problema di business."
- Chi siamo, cosa facciamo, perché adesso

### Atto 2 — La visione: da reattivo a predittivo (minuti 7-11)
- Il cambio di paradigma: da "rompi → ripara" a "prevedi → prepara → preserva"
- Le quattro leve di HangarMind (RUL, spare parts, EASA automation, knowledge)
- I risultati attesi (tabella KPI before/after — visual forte, una sola slide)
- Non è un progetto IT, è una trasformazione operativa

### Atto 3 — L'architettura della soluzione (minuti 11-20) ⬅ CUORE CSA
Questo è il momento in cui il CSA "apre il cofano" e mostra come la soluzione sta in piedi.

**3A — Vista d'insieme (1 diagramma architetturale, 2-3 minuti)**
- Diagramma end-to-end: edge/IoT → ingestion → data platform → AI/ML → app layer → utenti
- Landing Zone: hub-spoke networking, subscription topology
- Flusso dati: dalla telemetria OEM fino alla dashboard e alla task card

**3B — Pillar: Security & Zero-Trust (3-4 minuti)**
- Network isolation: hub-spoke, private endpoints, nessun public exposure
- Identity: Entra ID, PIM, Managed Identity, RBAC fine-grained
- Data protection: encryption at rest (CMK) + in transit (TLS 1.3)
- Secrets: Key Vault, no credentials in code
- Monitoring: Sentinel, Defender for Cloud, threat detection
- → Diagramma: "nessun dato esce dalla rete privata"

**3C — Pillar: Scalabilità & Reliability (2-3 minuti)**
- Compute: Container Apps (auto-scale), Azure ML managed endpoints (blue-green)
- Data: ADLS Gen2 + Delta Lake (petabyte-ready), Fabric per analytics
- Resilienza: multi-AZ, DR strategy, RPO/RTO targets
- Elasticità: da 340 aeromobili oggi a 500+ domani senza re-architecture
- → Messaggio: "la piattaforma scala con il business, non è un PoC"

**3D — Pillar: Cost Management & FinOps (2-3 minuti)**
- Modello di costo: pay-per-use vs. reserved (ML compute, storage tiers)
- Leve di ottimizzazione: spot instances per training, hot/cool/archive per i dati storici
- TCO confronto: costo piattaforma vs. costo attuale AOG + doc + ricambi sbagliati
- Governance costi: budget alerts, cost anomaly detection, tagging strategy
- → Messaggio: "non è un costo IT, è un investimento con payback misurabile"

**3E — Pillar: Governance & Observability (1-2 minuti)**
- Azure Policy: guardrail su region, SKU, encryption, tagging
- Purview: data catalog, lineage, classification automatica
- AI audit log: ogni inferenza tracciata su immutable blob (EU AI Act ready)
- Monitoring: Application Insights, Log Analytics, workbook operativi

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

## 4. Principi di storytelling da seguire

1. **Regola del "So what?"** — Ogni slide deve superare il test "e quindi?" Se non porta a un'azione o decisione, via.

2. **Numeri con contesto** — Mai un numero solo. Sempre: prima → dopo, o confronto con benchmark industry. "11 ore di AOG" non dice nulla se non dici che la media IATA è 6.

3. **La piramide di Minto** — Parti dalla conclusione ("HangarMind riduce i costi del X% e ci rende compliant"), poi giustifica con i pillar, poi dettaglia. Non arrivare alla conclusione alla fine.

4. **Show, don't tell** — Almeno 2 momenti "wow": una demo live, uno screenshot reale, un dato controintuitivo. I C-level vedono 50 presentazioni al mese, devi differenziarti.

5. **L'analogia del ponte** — Ogni volta che passi da un atto all'altro, usa una frase-ponte che lega il vecchio al nuovo. Es: "Ora sappiamo che il motore sta per guastarsi. Ma il pezzo di ricambio dov'è?" → transizione naturale da AI-01 a AI-02.

6. **Chiudi il cerchio** — La storia dell'Hangar 7 torna nell'atto 5. Il pubblico ricorda l'inizio e la fine, raramente il mezzo.

---

## 5. Idee per momenti "wow" / differenzianti

- **Il semaforo RUL live** — Mostra un motore che passa da verde a giallo con i dati che scorrono. Anche simulato, è potente.
- **La voce del tecnico** — Fai partire un audio (anche registrato) di un tecnico che detta una finding, e mostra la task card che si compila in tempo reale. È il momento più cinematografico.
- **Il before/after della task card** — Due colonne: a sinistra una task card compilata a mano (lunga, imprecisa, senza riferimenti). A destra quella generata dall'AI (strutturata, con citazioni EASA, con effectivity). Visivamente devastante.
- **La mappa dei 12 hangar** — Una mappa d'Europa con i 12 hangar, le scorte, i flussi di trasferimento. Mostra il problema della frammentazione e come il sistema lo risolve.
- **Il "costo di Jean-Pierre"** — Calcola quanto costa non codificare il sapere: costo di ri-training × numero di senior in uscita × tasso di errore dei junior. Numero grande, impatto emotivo.

---

## 6. Rischi di comunicazione da evitare

| Rischio | Mitigazione |
|---------|-------------|
| Troppo tecnico per il CFO | Tenere i dettagli ML nell'appendice. Nel main deck: input → output → beneficio |
| Troppo vago per il CTO | Avere slide di backup con architettura, stack, modelli. Pronte per le domande |
| Sottovalutare il CISO | Dedicare tempo esplicito a compliance e sicurezza. Non è un afterthought |
| Presentazione troppo lunga | 40 minuti sono 25-28 slide MAX. Meno è meglio. Prevedere 10 min di Q&A |
| Demo che fallisce | Avere sempre screenshot/video di backup. Mai demo live senza piano B |
| Nessuna call-to-action | Chiudere SEMPRE con: "Vi chiediamo X, entro Y, per ottenere Z" |

---

## 7. Temi aperti / da decidere

- [ ] Quanto tempo dedicare alla demo vs. storytelling? (proposta: 60% storia, 40% demo)
- [ ] Mostriamo l'architettura Azure in dettaglio o solo a blocchi? (proposta: blocchi nel main, dettaglio in appendice)
- [ ] Inseriamo un confronto competitivo? (rischio: distrae; vantaggio: posiziona)
- [ ] Includiamo un TCO/ROI quantitativo? (il CFO lo vuole, ma i numeri devono essere difendibili)
- [ ] Lingua delle slide finali: EN o misto? (proposta: slide in EN, speaker notes in IT, presentazione orale in IT)
- [ ] Quante persone presentano? Se sono più di una, servono transizioni pulite

---

## 8. Scaletta timing (bozza)

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
