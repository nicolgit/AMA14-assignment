# aircraft — descrizione delle colonne

questo file documenta lo schema di [aircraft.csv](aircraft.csv), l'anagrafica degli aeromobili usata nel PoC.

l'oggetto `aircraft` fa da **contenitore di contesto**: raggruppa i motori e fornisce le informazioni operative necessarie per la decisione di manutenzione. il cuore predittivo (RUL e semaforo) resta a livello di **motore** (`engine_id` = `unit_id` C-MAPSS); l'aircraft serve a collegarli e a dare il contesto operativo.

## colonne

| Colonna | Tipo | Esempio | Significato |
|---|---|---|---|
| `aircraft_id` | string | `EI-ABC` | chiave primaria: tail number / registration dell'aeromobile |
| `model` | string | `A320-200` | tipo di aeromobile (contesto flotta e tipo motore) |
| `engine_count` | int | `2` | numero di motori installati da monitorare |
| `engine_ids` | string | `ENG-001;ENG-002` | elenco dei motori installati, separati da `;`. è l'aggancio al modello RUL (ogni id = `unit_id` C-MAPSS) |
| `operator` | string | `SkyAlpha` | operatore / compagnia a cui appartiene l'aeromobile |
| `total_flight_cycles` | int | `18450` | cicli di volo totali accumulati (un ciclo = decollo + atterraggio). il RUL è espresso in cicli |
| `status` | enum | `in-service` | stato operativo: `in-service`, `in-maintenance`, `AOG` (Aircraft On Ground) |
| `msn` | string | `MSN-2871` | manufacturer serial number: identificativo univoco assegnato dal costruttore, per la tracciabilità reale del cespite |
| `in_service_date` | date (ISO `YYYY-MM-DD`) | `2014-03-12` | data di entrata in servizio, usata per ricavare l'età dell'aeromobile |
| `total_flight_hours` | int | `32100` | ore di volo totali accumulate; alcune soglie di manutenzione sono espresse in ore anziché in cicli |
| `base_location` | string (IATA) | `MXP` | base operativa principale, dove pianificare lo slot hangar; entra nel calcolo del lead time. sono 12 angar che devono essere in una di queste nazioni: France, Germany, the United Kingdom, Spain, and the Netherlands |

## note

* `engine_ids` usa il separatore interno `;` per non confliggere con la virgola delimitatrice del CSV.
* `status` con valore `AOG` indica un aeromobile fermo a terra non programmato: caso prioritario per la decisione di manutenzione.
* `total_flight_cycles` e `total_flight_hours` sono valori cumulati a livello di aeromobile; il consumo per singolo motore può differire (es. dopo una sostituzione motore).
