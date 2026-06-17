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

# Raccomandazione RUL per questo scenario
Modello consigliato: **CNN-LSTM per regressione RUL**. È una scelta solida per telemetria motore perché cattura sia i pattern locali dei sensori sia la dipendenza temporale nel degrado. Come alternativa più semplice da baseline, si può usare CatBoost sui feature aggregati; per il modello operativo, però, CNN-LSTM è più adatto allo scenario descritto.

Dataset consigliato per training e test: **NASA C-MAPSS, preferibilmente FD004**.
- **Training**: `train_FD004` ufficiale, con una validation split ricavata dagli ultimi cicli di una parte degli engine del training set.
- **Test**: `test_FD004` ufficiale con i relativi RUL label.
- **Perché FD004**: contiene più operating conditions e fault modes, quindi è più vicino a un contesto MRO reale rispetto a FD001.

> Specificità di FD004
> FD004 è il dataset più complesso dei quattro:
> 6 condizioni operative diverse (non solo livello del mare)
> 2 modalità di guasto (degrado HPC – High Pressure Compressor + degrado della ventola/Fan)
> 248 traiettorie di training, 249 di test

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

# Come si leggono i file train / test / RUL

Il file `RUL_FD004.txt` contiene il **vettore di "verità" (ground truth)** del dataset NASA C-MAPSS FD004, usato per valutare i modelli di manutenzione predittiva.

## Cosa contiene

Una sola colonna di numeri interi: **un valore per riga**. Ogni riga corrisponde a un motore (engine/unit) del set di test, nell'ordine.

| Riga | Valore | Motore |
| --- | --- | --- |
| 1 | 22 | motore di test #1 |
| 2 | 39 | motore di test #2 |
| 3 | 107 | motore di test #3 |
| ... | ... | ... fino a tutti i **249 motori** di test di FD004 |

## Cosa significa il numero

Ogni valore è il **RUL (Remaining Useful Life)** = il numero di cicli operativi residui prima del guasto, calcolato a partire dall'ultimo ciclo presente per quel motore nel file `test_FD004.txt`.

Il meccanismo è questo:

- Nel **training set**, ogni serie temporale arriva fino al guasto completo del motore.
- Nel **test set**, la serie temporale viene troncata in un punto casuale prima del guasto.
- Il file RUL dice quanti cicli mancavano ancora al guasto da quel punto di troncamento.

> **Esempio:** se il motore #1 nel file di test ha l'ultima riga al ciclo 150, il valore `22` significa che quel motore si sarebbe guastato al ciclo **172** (150 + 22).

## Ruolo nel progetto

È l'**etichetta target** per valutare l'accuratezza del modello:

$$\text{errore}_i = \text{RUL}_{\text{predetto},i} - \text{RUL}_{\text{vero},i}$$

Il modello (CNN-LSTM nel tuo workspace) riceve in input le serie dei sensori dal test set e predice il RUL; questi valori "veri" servono a misurare le metriche (RMSE, score NASA, ecc.).

## Specificità di FD004

FD004 è il dataset **più complesso** dei quattro:

- **6 condizioni operative** diverse (non solo livello del mare)
- **2 modalità di guasto** (degrado HPC – High Pressure Compressor + degrado della ventola/Fan)
- **248 traiettorie** di training, **249** di test

Questo rende la predizione del RUL più difficile rispetto a FD001/FD003, perché il modello deve distinguere il degrado reale dal "rumore" introdotto dalle diverse condizioni operative.