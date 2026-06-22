un sistema **MRO (Maintenance, Repair, Overhaul)** nel contesto aeronautico ha l'obiettivo di garantire che le attrezzature, gli impianti o gli aeromobili siano mantenuti in condizioni di sicurezza, affidabilità ed efficienza durante tutto il loro ciclo di vita.

nel workflow di un sistema MRO il passo "**Detect & Inspect**" è fondamentale:  è la fase iniziale di monitoraggio e individuazione dei problemi. in questa fase vengono raccolti i dati sullo stato dell'aeromobile dei componenti e degli impianti. obiettivo principale è:

* identificare tempestivamente guasti
* evitare interruzioni operative
* garantire affidabilità e continuità di servizio

in questa fase come ci può aiutare l'AI? mettendoci a disposizione un sistema che permetta di prevedere il **RUL - remaining useful time** ovvero il numero di cicli di funzionamento che in un dato istante restano ad una componente dell'aereo. Nel momento in cui riusciamo a prevedere con precisione quando un componente si romperà, potremo fare delle operazioni di manutenzione programmata e preventiva che permetteranno di eliminare il rischio di malfuzionamento inaspettato e aumento delle ore di AOG (aircraft on ground).

Un modello RUL, in sostanza 'impara' una curva di degradazione:

- Prende i dati sensoriali del motore nel tempo
- Impara come questi segnali cambiano quando ci si avvicina a un guasto
- Stima la distanza temporale dal prossimo evento
- È come un “contachilometri inverso” del motore. 

# Categorie di modelli utilizzabili in ambito RUL
esistono 3 principali categorie di modelli utilizzabili in questo ambito:

* classici
* Time series
* Deep Learning

I modelli classici usano metodi tradizionali di previsione come regressione, survival analysis etc. si usano feature estratte da sensori e storico dei guasti.

I modelli Time series sono modelli pensati per dati sequenziali si basano su serie storiche continue

I modelli deep learning richiedono invece serie lunghe, una normalizzazione accurata ed un ampio dataset

dimensione del dataset:

* classico: ~**100** step temporali e 10...30 sensori - approccio tabellare con valori medi
* time series: fino a ~**500** step temporali, 20-50 sensori - maggior dettaglio, in ogni istante ci sono tutti i dati provenienti dai sensori
* Deep learning: +**1000** step temporali 20-100 sensori - finestra di osservazione più lunga, molti più dati

> la cosa importante è che, per il training, sono necessarie delle serie temporali che arrivano sino al punto di rottura del motore, ovvero il **RUN-TO-FAILURE**

L'approccio deep learning è lo standard de facto nel 2026

a livelli di dati sono necessari
- centinaia di unità (i.e. motori)
- +500 cicli monitorati

la best practice è usare un modello ibrido, ad esempio il **CNN+LSTM**
- **CNN** Convolutional neural network
- **LSTM** long/short term memory

CNN processa i dati alla ricerca di piccoli pattern ripetibili, LSTM funge da memoria, analizza i pattern trovati con la CNN e riesce a ricavare un trend ed evoluzione temporale.

# come fare il training del modello

partendo dall'algoritmo (CNN+LSTM) e dalle sequenze RUN-TO-FAILURE (train_FD*) si arriva alla definizione di un modello.

un modello è definito da 3 file:

- `model.pt`: pesi e config dell'algoritmo CNN-LSTM
- `scaler.pkl`: lo standard scaler fitted sul train
- `metrics.json`: metrica che serve a tracciare la qualità del modello

# come fare l'evaluate del modello generato
L'idea di fondo è la seguente: prendere il modello addestrato e misurarne la **bravura** su motori mai visti (il set test_FD*), confrontando le predizioni con le risposte vere.

la sequenza test di CMAPSS è troncato: la serie si ferma "**a un certo punto prima del guasto**" e la domanda è "**quanto RUL resta da QUEL momento?**"

il modello fa una sua predizione e salva il risultato in predictions.csv (engine_id → predicted_rul).

il file RUL_FD* contiene invece, per tutti i motori test_fd* il **vero RUL**.
confrontando il vero RUL con quello calcolato si può valutare la qualità del modello prodotto. l'indice di qualità del modello sono i 2 parametri

* MAE (Mean Absolute Error) – errore medio assoluto
  - Un MAE = 15 significa "in media sbaglio di 15 cicli"
* RMSE (Root Mean Squared Error) – radice dell'errore quadratico medio
  - misura quanto sono gravi i miei errori peggiori. Se RMSE è molto più alto di MAE, vuol dire che hai pochi motori con errori enormi (outlier)

dalle sequenze di training di CMAPPS

| Metrica | Valore | Lettura |
|---------|--------|---------|
| MAE | ≈ 25,9 cicli | In media il modello sbaglia di circa 26 cicli |
| RMSE | ≈ 34,4 cicli | Gli errori "pesati sui peggiori" valgono circa 34 cicli |

> il valore calcolato sopra, È un buon punto di partenza, con spazio di miglioramento soprattutto sulla normalizzazione per condizione operativa.

# dal RUL alla decisione di manutenzione

il RUL da solo **non basta** per pianificare la riparazione: è un input necessario ma non sufficiente. ci dice *quanto manca*, non *cosa fare*, *quando conviene farlo*, né *con quale fiducia*.

per trasformare il RUL in una decisione servono altri elementi:

* **incertezza della stima**: un RUL puntuale (es. 30 cicli) senza margine è pericoloso. con un RMSE ≈ 34 cicli, una predizione di 30 potrebbe in realtà essere 10 o 60. servono intervalli di confidenza o una distribuzione, e si ragiona su un percentile prudenziale (es. 10°), non sulla media.
* **criticità del componente**: lo stesso RUL ha implicazioni diverse a seconda che il componente sia safety-critical (no ridondanza → intervento anticipato con ampio margine) o ridondato/non critico (si può attendere). questa informazione viene dalla FMEA, non dal modello.
* **vincoli operativi e logistici**: disponibilità di hangar, slot di manutenzione, personale certificato, lead time del ricambio, piano di volo dell'aeromobile, raggruppamento con interventi già schedulati.
* **quadro normativo (EASA / Part-145)**: esistono intervalli prescritti, task card e limiti di vita certificati. il RUL può anticipare un intervento ma non può violare gli obblighi regolamentari né sostituire l'approvazione di un certifying staff.
* **policy costo-rischio**: una soglia di decisione che bilancia il costo di un intervento anticipato (spreco di vita utile residua) contro il costo di un guasto non previsto (AOG, safety, penali).

la catena reale dalla predizione alla decisione:

```text
RUL stimato + incertezza
      │
      ├─ criticità componente (FMEA)
      ├─ vincoli ricambi / hangar / slot
      ├─ obblighi EASA / Part-145
      └─ policy costo-rischio
      ▼
  Decisione di manutenzione (cosa, quando, dove, chi)
```

> in sintesi: il RUL è il **punto di partenza, non il punto di arrivo**. risponde a "quanto manca?"; la pianificazione deve rispondere anche a "con quanta certezza, quanto è critico, ho il pezzo, è conforme alle regole, e conviene farlo ora?". in un sistema MRO il modello RUL alimenta un livello decisionale (regole + ottimizzazione + human-in-the-loop) che è ciò che produce davvero il piano di intervento.

# algoritmo a soglia conservativa + semaforo

per aiutare il man-in-the-loop a decidere se fare la riparazione preventiva, l'idea chiave è **non usare mai il RUL puntuale**, ma un limite inferiore prudenziale costruito sull'errore del modello (RMSE). l'algoritmo produce un "semaforo" (verde / giallo / rosso) che traduce un numero incerto in una raccomandazione chiara.

## passo 1 — trasforma la predizione in un RUL conservativo

si usa l'RMSE come stima dell'incertezza per "scontare" la predizione:

$$RUL_{safe} = RUL_{pred} - z \cdot RMSE$$

dove $z$ è il fattore di prudenza (quanto si vuole essere cauti):

* $z = 1$ → copre ~84% dei casi (lato sicuro di 1σ)
* $z = 1.65$ → ~95%
* $z = 2$ → ~97,7%

per un componente safety-critical si usa $z$ alto; per uno non critico $z$ basso.

> esempio con RMSE ≈ 34: se il modello predice $RUL_{pred} = 80$ e si sceglie $z = 1.65$, allora $RUL_{safe} = 80 - 1.65 \cdot 34 \approx 24$ cicli. cioè: "con buona confidenza, restano **almeno** ~24 cicli".

il **MAE** si usa per comunicare all'operatore l'errore tipico atteso ("in media ±26 cicli"); l'**RMSE** si usa per dimensionare il margine di sicurezza, perché pesa di più gli errori gravi (le sovrastime pericolose).

## passo 2 — confronta con il lead time richiesto

si definisce il tempo necessario per intervenire, espresso in cicli:

$$LT = LT_{ricambio} + LT_{slot/hangar} + LT_{buffer}$$

è il "reorder point": se la vita residua sicura scende sotto il tempo che serve per organizzare l'intervento, bisogna agire ora.

## passo 3 — classifica in zone (il semaforo)

| Condizione | Zona | Raccomandazione al man-in-the-loop |
|---|---|---|
| $RUL_{safe} > LT + margine$ | 🟢 verde | Nessuna azione, continua a monitorare |
| $LT < RUL_{safe} \le LT + margine$ | 🟡 giallo | Pianifica intervento / ordina ricambio, decisione umana |
| $RUL_{safe} \le LT$ | 🔴 rosso | Intervento preventivo raccomandato ora |

in pseudocodice:

```python
def raccomanda(rul_pred, rmse, z, lead_time, margine):
    rul_safe = rul_pred - z * rmse
    if rul_safe <= lead_time:
        return "ROSSO", "Intervento preventivo ora"
    elif rul_safe <= lead_time + margine:
        return "GIALLO", "Pianifica / ordina ricambio"
    else:
        return "VERDE", "Continua monitoraggio"
```

## limite da dichiarare

l'RMSE è un errore **medio globale** sul test set: usarlo come σ per ogni singola predizione è un'approssimazione, perché l'incertezza reale varia da motore a motore e cresce quando il RUL è alto. il salto di qualità è far produrre al modello un'incertezza **per-predizione** (quantile regression, MC-dropout, o ensemble) invece di un singolo numero. come prima versione, però, l'RMSE come proxy è una scelta pragmatica e difendibile.

