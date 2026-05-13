## EU AI Act: sintesi e impatto su un progetto MRO

L'**EU AI Act** (Regolamento UE 2024/1689, in vigore da agosto 2024, con applicazione progressiva fino al 2027) è il primo framework regolatorio al mondo sull'intelligenza artificiale. La logica centrale è una classificazione per livello di rischio: più alto è il rischio, più stringenti sono gli obblighi.

**La struttura a quattro livelli:**

Il regolamento distingue sistemi AI a rischio inaccettabile (vietati tout court, es. social scoring), ad alto rischio (soggetti a obblighi pesanti), a rischio limitato (solo obblighi di trasparenza), e a rischio minimo (liberi). Un progetto MRO interseca quasi certamente la categoria ad alto rischio.

Ecco prima la mappa dei livelli di rischio, poi gli impatti concreti sul contesto MRO.Un progetto MRO in aviazione ricade quasi certamente nella categoria **ad alto rischio** (Allegato III del regolamento), perché i sistemi AI vengono usati in infrastrutture critiche per la sicurezza — manutenzione di aeromobili, rilevamento guasti, pianificazione di ispezioni. Vediamo ora gli obblighi concreti che ne derivano.---

### Impatti concreti per area in un progetto MRO

**1. Sistemi di predizione guasti e manutenzione predittiva**
Questi sono il cuore dell'AI in MRO. Un modello che predice quando un componente cederà, o che suggerisce di anticipare un'ispezione, è classificabile ad alto rischio perché incide direttamente sulla sicurezza del volo. L'obbligo principale è dimostrare accuratezza misurata, con soglie definite, su dati rappresentativi — e mantenere log completi di ogni inferenza.

**2. Sistemi di supporto alle decisioni dei tecnici**
Se un sistema AI raccomanda una procedura di riparazione o segnala un'anomalia, deve essere progettato con supervisione umana esplicita: il tecnico deve poter capire il ragionamento, ignorare il suggerimento, e questa possibilità deve essere documentata nel design. Non è sufficiente che il tecnico "possa" ignorarlo — deve esserci un'interfaccia che renda il controllo umano attivo e tracciato.

**3. Sistemi di ispezione visiva automatizzata (computer vision)**
La rilevazione automatica di cricche, corrosione o usura tramite AI rientra chiaramente nell'alto rischio. Occorrono dataset di training validati, documentazione del processo di sviluppo del modello, e test di robustezza contro condizioni avverse (illuminazione, angolazioni diverse, componenti degradati).

**4. Pianificazione automatizzata di slot e risorse**
Sistemi che ottimizzano scheduling di hangar, slot di manutenzione, disponibilità dei tecnici — se integrati con decisioni safety-critical — possono ricadere nell'alto rischio. Se invece sono puramente logistici e disconnessi dalla catena di sicurezza, il livello scende.

**5. AI generativa e LLM per documentazione tecnica**
L'uso di modelli linguistici per generare o sintetizzare manuali, procedure AMM, o report di manutenzione è soggetto agli obblighi di trasparenza (il contenuto deve essere dichiarato come AI-generated). Se l'output alimenta direttamente un processo certificativo, il livello di rischio sale.

---

### Confronto sintetico con il GDPR

| Dimensione | GDPR | EU AI Act |
|---|---|---|
| Oggetto | Dati personali | Sistemi AI |
| Approccio | Principi + diritti | Rischio-based + conformità |
| Chi è obbligato | Titolare del trattamento | Provider + deployer del sistema AI |
| Autorità | Garante Privacy (es. GPDP) | Autorità nazionale AI (da designare) + EUDB |
| Sanzioni | Fino a 20M € / 4% fatturato | Fino a 30M € / 6% fatturato |
| Timing in MRO | Immediato (già vigente) | Progressivo — alto rischio da feb 2026 |

La chiave per un progetto MRO è che i due regolamenti si sovrappongono: un sistema AI che analizza dati di tecnici o piloti è contemporaneamente soggetto al GDPR (per i dati personali) e all'AI Act (per il sistema in sé). La governance deve essere pensata in modo integrato fin dall'architettura del progetto.