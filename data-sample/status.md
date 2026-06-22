# status — descrizione delle colonne

questo file documenta lo schema di [status.csv](status.csv), l'anagrafica degli stati operativi di un aeromobile.

il campo `status` in [aircraft.csv](aircraft.csv) è una chiave esterna verso `status_code` di questo file. lo stato determina la priorità nella decisione di manutenzione (es. un `AOG` è prioritario).

## colonne

| Colonna | Tipo | Esempio | Significato |
|---|---|---|---|
| `status_code` | enum | `in-service` | chiave primaria: codice stato; referenziato da `status` in aircraft.csv |
| `status_name` | string | `In Service` | nome leggibile dello stato |
| `description` | string | `Aeromobile operativo e in linea di volo` | spiegazione del significato operativo dello stato |

## valori ammessi

| `status_code` | significato |
|---|---|
| `in-service` | aeromobile operativo e in linea di volo |
| `in-maintenance` | fermo per manutenzione programmata o in corso |
| `AOG` | Aircraft On Ground: fermo a terra non programmato (guasto/indisponibilità), caso prioritario |
