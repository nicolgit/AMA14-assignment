Ecco una sintesi del GDPR e del suo impatto su un progetto MRO.

---

## GDPR: cosa contiene

Il **Regolamento Generale sulla Protezione dei Dati** (UE 2016/679) si applica a qualsiasi organizzazione che tratta dati personali di residenti UE. I pilastri fondamentali sono:

**Principi cardine** — i dati vanno trattati con liceità, trasparenza, minimizzazione (raccogliere solo ciò che serve), limitazione della finalità, accuratezza, limitazione della conservazione, integrità e riservatezza.

**Diritti degli interessati** — accesso, rettifica, cancellazione ("diritto all'oblio"), portabilità, opposizione al trattamento, limitazione.

**Obblighi del titolare** — base giuridica per ogni trattamento (consenso, contratto, legittimo interesse, obbligo legale), designazione del DPO se necessario, registri delle attività, DPIA per trattamenti ad alto rischio, notifica delle violazioni entro 72 ore.

**Trasferimenti internazionali** — consentiti solo verso paesi adeguati o con garanzie specifiche (clausole contrattuali standard, BCR).



---

## Impatto in un progetto MRO

Un progetto di Manutenzione, Riparazione e Revisione tratta inevitabilmente dati personali: tecnici, piloti, clienti, fornitori, addetti alla certificazione. Di seguito la mappa degli impatti.---

### Aree di impatto specifico in un progetto MRO

**1. Personale tecnico e certificazioni**
I dati di tecnici abilitati (licenze EASA/FAA, specializzazioni, turni) sono dati personali. Occorre una base giuridica (tipicamente il contratto di lavoro o l'obbligo legale), una policy di conservazione allineata ai requisiti regolatori dell'aviazione (spesso 5–10 anni), e controlli di accesso granulari nei sistemi CMMS/ERP.

**2. Clienti e operatori aerei**
I contratti, le comunicazioni e i dati di contatto dei referenti vanno gestiti con informativa adeguata. Se si trattano dati di piloti o passeggeri anche indirettamente, la sensibilità aumenta.

**3. Supply chain e accessi di terzi**
Ogni fornitore che accede a sistemi contenenti dati personali diventa un "responsabile del trattamento": occorre un DPA (Data Processing Agreement) contrattuale. Questo vale per i vendor di software MRO in cloud, per i fornitori di parti che accedono al portale ordini, per i consulenti on-site.

**4. Sistemi digitali — ERP, CMMS, log**
I log di accesso ai sistemi contengono dati personali (chi ha fatto cosa e quando). Vanno gestiti con retention definita, pseudonimizzazione ove possibile, e accesso ristretto.

**5. Trasferimenti internazionali**
MRO è spesso un contesto globale: se i dati finiscono su server USA o vengono condivisi con centri di manutenzione extra-UE, servono garanzie adeguate (Standard Contractual Clauses, decisioni di adeguatezza).

**6. Incident reporting e audit trail**
I registri di eventi di manutenzione (obbligatori per sicurezza aerea) possono contenere dati personali. Va bilanciato il requisito regolatorio di sicurezza con il principio di minimizzazione GDPR.

---

### Checklist di progetto

| Azione | Priorità |
|---|---|
| Mappare tutti i flussi di dati personali (data mapping) | Alta |
| Definire base giuridica per ogni trattamento | Alta |
| Firmare DPA con tutti i vendor cloud/software | Alta |
| Valutare se serve il DPO | Media |
| Eseguire DPIA per sistemi ad alto rischio (es. monitoraggio biometrico) | Media |
| Definire retention policy allineata a requisiti EASA/ICAO | Media |
| Predisporre procedura di gestione violazioni (72h) | Alta |

La buona notizia è che molti obblighi GDPR (tracciabilità, controllo accessi, audit trail) si sovrappongono ai requisiti di qualità già previsti dagli standard aeronautici come AS9100 o i regolamenti EASA Part-145, riducendo il delta implementativo.