Per costruire una piattaforma di MRO Intelligence che preveda la domanda di ricambi e ottimizzi i livelli di scorta, devi partire da:


La soluzione deve prevedere 2 modelli nel caso di componenti con telemetria (es. motore dell'aereo)

# Caso 1 componenti con telemetria

esempio il motore dell'aereo

Un modello RUL 'impara' una curva di degradazione.
- Prende i dati sensoriali del motore nel tempo
- Impara come questi segnali cambiano quando ci si avvicina a un guasto
- Stima la distanza temporale dal prossimo evento
- È come un “contachilometri inverso” del motore.

Una volta che hai il RUL per ogni motore:
- Converti il RUL in probabilità di guasto nei prossimi X giorni
- Converti la probabilità in domanda prevista di ricambi
- Usi questa domanda per ottimizzare:
  - livelli di scorta
  - safety stock
  - posizionamento nei magazzini
  - lead time dei fornitori

a questo punto ci vuole un algoritmo di inventory optimization classica
- ROP (Reorder Point)
- EOQ (Economic Order Quantity)
- Safety Stock basato su variabilità + livello di servizio

esempio **Reorder Point** (Supply Chain / Finance).

In inventory management, the Reorder Point (ROP) algorithm is a formula that dictates exactly when a business must place a new order to replenish stock without running out (stockout).

The Algorithm/Formula:\(\text{ROP} = (\text{Average Daily Sales} \times \text{Average Lead Time in Days}) + \text{Safety Stock}\)

- Average Daily Sales: The average number of items sold per day.
- Average Lead Time: The number of days it takes for a supplier to deliver the goods.
- Safety Stock: Extra inventory kept on hand to buffer against unexpected demand or supply delays.

# Case 2 componenti senza telemetria
quì non c`è telemetria, in particolare ci sono delle cose che vanno sostituite periodicamente e che se non ci sono nei magazzini vanno ordinate
si rompe un sedile.
in questo caso si può usare un algoritmo di tipo Croston per calcolare la scorta di magazzino per questo tipo di componente

# Su hugging face
dataset FD001/FD002/FD004 già normalizzati, clusterizzati per regime, con modelli CatBoost RUL https://huggingface.co/spaces/Dakoro/CMAPSS_Predictive_Maintenance_Dashboard
modello di test già pre-addestrato: https://huggingface.co/penikmatrumput/cnn-lstm-cmapss 
