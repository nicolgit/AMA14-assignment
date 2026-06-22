# location — descrizione delle colonne

questo file documenta lo schema di [location.csv](location.csv), l'anagrafica delle basi/aeroporti usati nel PoC.

le location rappresentano le **basi operative** dove sono di stanza gli aeromobili e dove si pianificano gli slot hangar per la manutenzione. il campo `base_location` in [aircraft.csv](aircraft.csv) è una chiave esterna verso `location_code` di questo file. vincolo del PoC: le basi appartengono solo a Francia, Germania, Regno Unito, Spagna e Paesi Bassi.

## colonne

| Colonna | Tipo | Esempio | Significato |
|---|---|---|---|
| `location_code` | string (IATA) | `FCO` | chiave primaria: codice aeroporto IATA a 3 lettere; referenziato da `base_location` in aircraft.csv |
| `location_name` | string | `Fiumicino Airport` | nome esteso dell'aeroporto |
| `place` | string | `Italy` | Paese in cui si trova l'aeroporto |

## note

* `location_code` è la chiave di join con `base_location` di [aircraft.csv](aircraft.csv).
* nel PoC `place` può assumere solo i 5 Paesi consentiti per gli hangar: France, Germany, United Kingdom, Spain, Netherlands.
* l'elenco contiene solo le location effettivamente presenti in aircraft.csv (9 aeroporti).
