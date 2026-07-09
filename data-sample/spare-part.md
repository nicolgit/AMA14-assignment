# spare-part — descrizione delle colonne

questo file documenta lo schema di [spare-part.csv](spare-part.csv), l'anagrafica dei ricambi usati nel PoC.

l'oggetto `spare-part` rappresenta il catalogo base dei ricambi gestiti dal sistema, indipendentemente dalla location in cui sono stoccati.

## colonne

| Colonna | Tipo | Esempio | Significato |
|---|---|---|---|
| `part_number` | string | `PN-001` | chiave primaria: codice univoco del ricambio |
| `name` | string | `Fuel Pump` | nome descrittivo del ricambio |

## note

* `part_number` e la chiave di join verso i file di stock e movimentazione ricambi.
* questo file contiene solo il catalogo dei ricambi, non le quantita disponibili per location.
