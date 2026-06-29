# predictions — descrizione delle colonne

questo file documenta lo schema di [predictions.csv](../ml-outputs/predictions.csv), l'output del modello RUL caricato nella tabella `prediction` del PoC.

la tabella `prediction` contiene la **Remaining Useful Life** stimata dal modello CNN-LSTM per ciascun motore (`engine_id` = `unit_id` C-MAPSS). è il cuore predittivo della piattaforma: collega ogni motore alla sua vita utile residua espressa in cicli di volo.

## colonne

| Colonna | Tipo | Esempio | Significato |
|---|---|---|---|
| `engine_id` | int | `1` | chiave primaria: identificativo del motore (`unit_id` C-MAPSS); aggancio all'anagrafica `aircraft.engine_ids` |
| `predicted_rul` | float | `34.477047` | Remaining Useful Life stimata dal modello, espressa in cicli di volo residui prima del guasto |

## note

* `predicted_rul` è espressa in **cicli** (un ciclo = decollo + atterraggio), coerente con `aircraft.total_flight_cycles`.
* valori bassi di `predicted_rul` indicano motori prossimi alla soglia di manutenzione: input per il semaforo e la decisione di intervento.
* il file è generato dallo step di evaluation della pipeline ML (`evaluate.py`) e ricaricato in modo idempotente da [populate-sql.ps1](../powershell/populate-sql.ps1).
