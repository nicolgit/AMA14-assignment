# location-distance — descrizione delle colonne

questo file documenta lo schema di [location-distance.csv](location-distance.csv), la matrice semplificata di trasferimento tra coppie di location nel PoC.

l'oggetto `location-distance` rappresenta il tempo e il costo stimato per spostare un ricambio da una location a un'altra.

## colonne

| Colonna | Tipo | Esempio | Significato |
|---|---|---|---|
| `location_1` | string (IATA) | `CDG` | location di origine del trasferimento |
| `location_2` | string (IATA) | `AMS` | location di destinazione del trasferimento |
| `distance` | decimal | `398.50` | distanza stimata tra le due location, espressa in km |
| `transfer_time` | int | `3` | tempo stimato di trasferimento, espresso in cicli |
| `transfer_cost` | decimal | `450.00` | costo stimato del trasferimento tra le due location |

## note

* ogni riga descrive una relazione origine-destinazione tra due location.
* se il trasferimento non e simmetrico, la coppia `location_1` -> `location_2` va modellata separatamente da `location_2` -> `location_1`.
* `distance`, `transfer_time` e `transfer_cost` sono input della logica di scelta del ricambio.
* in questo dataset di prova, `distance` e calcolata dalle coordinate geografiche con formula Haversine.
* in questo dataset di prova, `transfer_time = ceil(distance / 400)` con minimo 1 ciclo.
* in questo dataset di prova, `transfer_cost = 120 + 0.75 * distance`.
