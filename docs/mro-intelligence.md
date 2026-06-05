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

# Raccomandazione RUL per questo scenario
Modello consigliato: **CNN-LSTM per regressione RUL**. È una scelta solida per telemetria motore perché cattura sia i pattern locali dei sensori sia la dipendenza temporale nel degrado. Come alternativa più semplice da baseline, si può usare CatBoost sui feature aggregati; per il modello operativo, però, CNN-LSTM è più adatto allo scenario descritto.

Dataset consigliato per training e test: **NASA C-MAPSS, preferibilmente FD004**.
- **Training**: `train_FD004` ufficiale, con una validation split ricavata dagli ultimi cicli di una parte degli engine del training set.
- **Test**: `test_FD004` ufficiale con i relativi RUL label.
- **Perché FD004**: contiene più operating conditions e fault modes, quindi è più vicino a un contesto MRO reale rispetto a FD001.

dataset: https://data.nasa.gov/dataset/cmapss-jet-engine-simulated-data 

## Uso pratico su Azure
Su Azure ML il flusso corretto è questo:
- carichi `train_FD004` in **Azure Data Lake Storage Gen2** o **Blob Storage** e lo registri come **data asset**;
- usi `train_FD004` per addestrare il modello e ricavare una **validation split** interna;
- usi `test_FD004` solo per la **valutazione offline** del modello, mai per l'inferenza online;
- quando il modello supera le metriche attese, lo registri nel **Azure ML registry** e lo pubblichi su un **online endpoint**;
- in produzione l'endpoint riceve telemetria nuova, calcola il RUL e restituisce il rischio di guasto; il test set non entra mai nel runtime.

In pratica:
- `train_FD004` = addestramento
- validation split = tuning e scelta del modello
- `test_FD004` = verifica finale prima del deploy
- online endpoint = inferenza sui dati reali dei motori

Guida operativa completa: [docs/azure-rul-cnn-lstm-step-by-step.md](docs/azure-rul-cnn-lstm-step-by-step.md)


Se serve un benchmark più realistico su telemetria aeronautica moderna, il passo successivo è **N-CMAPSS**; ma per un progetto didattico o PoC, **FD004** è il miglior punto di partenza.
