Il cloud-only su Azure apre un perimetro normativo specifico che va ben oltre il generico "cybersecurity" — entrano in gioco la residenza dei dati, la responsabilità condivisa, la certificazione del provider e i diritti di audit. Vediamo tutto in modo strutturato.

# Framework normativi

## Direttiva NIS2

Obblighi per essential entities — include aviazione e MRO

Il cloud-only amplifica l'esposizione ai rischi cyber trattati da NIS2. Usare Azure come unico punto di erogazione del servizio crea una dipendenza critica da un fornitore terzo: questo va dichiarato nel risk register e gestito con misure specifiche (multi-region, backup, SLA contractuali). La catena di fornitura cloud (Azure → Microsoft) rientra esplicitamente negli obblighi NIS2 di supply chain security.

Cosa fare: mappare Azure come "critical supplier", verificare che i contratti includano clausole di audit e notifica incidenti, predisporre un piano di continuità operativa in caso di outage Azure.

## EASA Cyber Regulation (UE 2023/203)

ISMS per organizzazioni Part-145 — ora include il cloud

Il regolamento EASA cybersecurity richiede un Information Security Management System (ISMS) che copra tutti i sistemi informativi usati nell'organizzazione MRO, incluse le soluzioni cloud. La guidance AMC/GM specifica che i servizi cloud di terzi devono essere valutati, contrattualizzati con clausole di sicurezza e monitorati continuativamente.

Cosa fare: includere Azure nel perimetro ISMS, effettuare una valutazione del rischio specifica per la configurazione cloud, documentare i controlli compensativi nel ISMS register.

## EU Data Act

Portabilità e accesso ai dati su cloud — in vigore set 2025

L'articolo 23–31 del Data Act introduce obblighi specifici per i cloud service providers, ma impatta anche i clienti cloud: diritto di switching verso altri provider, portabilità dei dati senza oneri sproporzionati, interoperabilità tecnica. Una soluzione cloud-only su Azure che non pianifica la data portability rischia di creare lock-in non conformi.

Cosa fare: progettare l'architettura con export dei dati in formato aperto, verificare che i contratti Azure prevedano switching assistance, documentare la strategia di exit nel design di progetto.

## DORA – Digital Operational Resilience Act

Rilevante se il MRO opera in contesti finanziari o assicurativi

DORA si applica direttamente a entità finanziarie (banche, assicuratori, leasing aeronautico), ma impatta indirettamente i MRO che forniscono servizi a questi soggetti o che gestiscono contratti Power-by-the-Hour con componenti finanziarie. I cloud provider critici (Microsoft Azure rientra tra i potenziali "critical ICT third-party providers") saranno soggetti a supervisione diretta dalle autorità europee.

Cosa fare: verificare se i clienti MRO (lessors, operatori con contratti finanziari) hanno obblighi DORA che si trasferiscono contrattualmente al MRO come ICT provider.

# Standard Internazionali

## ISO 27001 + 27017 + 27018

ISMS — con estensioni specifiche per il cloud

ISO 27001 è la base per qualsiasi ISMS. Le estensioni cloud-specific sono fondamentali per un progetto Azure: ISO 27017 aggiunge controlli specifici per cloud service customers (chi usa il cloud, come il MRO) e providers (Azure). ISO 27018 si focalizza sulla protezione dei dati personali nel cloud pubblico — il punto di raccordo con il GDPR in ambiente Azure.

Azure è certificato ISO 27001, 27017 e 27018: questo non esonera il MRO dall'obbligo di certificazione propria, ma semplifica la parte di controlli delegati al provider.

## Cloud Security Alliance STAR + SOC 2 Type II

Certificazioni cloud richieste dalla supply chain aeronautica

Il CSA STAR (Security Trust Assurance and Risk) è lo standard di riferimento per la valutazione della sicurezza dei cloud provider, basato sul Cloud Control Matrix (CCM). SOC 2 Type II è la certificazione richiesta da molti OEM e compagnie aeree come prerequisito per i loro fornitori software. Azure ha entrambe le certificazioni, ma il MRO deve dimostrare che la propria configurazione di Azure le soddisfa — non basta che Azure le abbia.