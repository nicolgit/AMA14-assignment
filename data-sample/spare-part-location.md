# spare-part-location — descrizione delle colonne

questo file documenta lo schema di [spare-part-location.csv](spare-part-location.csv), la disponibilita dei ricambi per singola location nel PoC.

l'oggetto `spare-part-location` rappresenta lo stato di stock del ricambio `part_number` nella location indicata.

## colonne

| Colonna | Tipo | Esempio | Significato |
|---|---|---|---|
| `part_number` | string | `PN-001` | chiave esterna verso `part_number` di spare-part.csv |
| `location` | string (IATA) | `CDG` | chiave esterna verso la location dove il ricambio e disponibile |
| `on_hand` | int | `5` | quantita fisicamente presente in quella location |
| `reserved` | int | `2` | quantita gia impegnata per altri interventi |
| `min_stock` | int | `1` | soglia minima di scorta che la location deve mantenere |

## note

* la coppia `part_number` + `location` identifica univocamente una riga di stock.
* la disponibilita effettiva si calcola come `on_hand - reserved`.
* `location` deve essere coerente con il dominio delle basi operative usate nel PoC.
