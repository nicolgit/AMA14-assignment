Azure porta in dote un portfolio di certificazioni che coprono una parte significativa degli obblighi normativi. La chiave è capire cosa si "eredita" automaticamente e dove invece il MRO deve intervenire con controlli propri.

> Certificazioni rilevanti per MRO EU su Azure

## **Disponibile** : ISO 27001 / 27017 / 27018

Copertura: infrastruttura Azure — non la configurazione MRO

Azure è certificato su tutti e tre. Il MRO può fare leva su queste certificazioni per la parte di controlli infrastrutturali, riducendo lo scope del proprio audit ISO 27001. Strumento utile: Microsoft Compliance Manager offre una shared responsibility matrix precompilata per ciascuno standard.

_Inherited controls_ - _Compliance Manager_ - _Audit reports disponibili_

## **Disponibile** : SOC 2 Type II + SOC 3

Copertura: richiesto da OEM e compagnie aeree come prerequisito fornitori

Azure ha SOC 2 Type II su tutti i servizi principali. Il MRO può presentare il report Azure agli auditor dei clienti come evidenza della sicurezza infrastrutturale, ma dovrà aggiungere il proprio SOC 2 (o equivalente) per la parte applicativa e di processo.

_SOC 2 Azure report_ - _Vendor questionnaire_ - _Customer attestation_

## **Disponibile** : EU Data Boundary + GDPR

Copertura: residenza dei dati in Europa — critica per GDPR e EASA

Microsoft ha dichiarato l'EU Data Boundary: i dati dei clienti UE rimangono processati in datacenter UE/EEA. Questo copre il requisito GDPR di trasferimento dati, ma va verificato servizio per servizio — alcuni servizi Azure (es. certi componenti di AI/ML) potrebbero ancora usare datacenter extra-UE. Verificare con il Microsoft Data Residency tool.

Per MRO con dati aeronautici sensibili, la region consigliata è West Europe (Amsterdam) o North Europe (Dublin) con geo-redundancy attiva.

_EU Data Boundary_ - _West Europe region_ - _Data residency tool_ - _SCC già incluse nel DPA_

## **Verificare** : ACN / AgID (Italia) — qualificazione cloud PA

Copertura: rilevante se il MRO ha contratti con enti pubblici italiani

Azure ha la qualificazione ACN (ex AgID) per i servizi cloud destinati alla Pubblica Amministrazione italiana, classificato come CSP qualificato. Se il progetto MRO coinvolge enti come ENAC, Aeronautica Militare o altri soggetti PA, la qualificazione ACN è prerequisito. Il Polo Strategico Nazionale (PSN) è l'alternativa sovrana per dati classificati.

_ACN qualificazione_ - _ENAC contratti_ - _PSN alternativa_ - _Circular 2/2017 AgID_

## **Attenzione** : NIS2: Azure come critical supplier

Copertura: Microsoft non è direttamente soggetto a NIS2 come vostro fornitore

NIS2 richiede che le essential entities gestiscano i rischi della supply chain ICT. Azure va formalmente qualificato come fornitore critico nel registro NIS2 del MRO. Microsoft offre le proprie certificazioni e il Microsoft Enterprise Agreement include clausole di sicurezza, ma la responsabilità della valutazione e del rischio di concentrazione (single cloud provider) rimane in capo al MRO.

_Critical supplier register_ - _Concentration risk_ - _EA security clauses_ - _Exit plan documentato_
