# CNN-LSTM RUL su Azure ML: guida passo per passo

Questo documento descrive come addestrare e distribuire su Azure un modello **CNN-LSTM per regressione RUL** usando il dataset **NASA C-MAPSS FD004**.

## 1. Obiettivo

Il flusso corretto è:
- usare `train_FD004` per addestramento e validation interna;
- usare `test_FD004` solo per la valutazione finale offline;
- registrare il modello validato in Azure ML Registry;
- pubblicare il modello su un **Azure ML Online Endpoint** per inferenza near-real-time.

## 2. Prerequisiti Azure

Serve questo set minimo di risorse:
- **Azure ML Workspace**
- **Storage account / ADLS Gen2** per i dataset
- **Azure ML Compute Cluster** per training
- **Azure ML Online Endpoint** per serving
- **Key Vault** per segreti e connessioni
- **Application Insights / Log Analytics** per monitoring

Se il progetto segue l'architettura del repository, i dati possono vivere in **ADLS Gen2** e il modello può essere gestito con **Azure ML registry + MLflow**.

## 3. Dati da usare

Usa il pacchetto NASA C-MAPSS e, per questo scenario, preferisci **FD004**.

- `train_FD004` = training
- validation split = tuning e selezione iperparametri
- `test_FD004` = test finale offline

Regola importante:
- **mai** usare `test_FD004` per il training;
- **mai** usare il test set nell'endpoint di produzione.

## 4. Preparazione dei dati

1. Scarica il pacchetto C-MAPSS dalla fonte NASA.
2. Estrai i file `train_FD004.txt` e `test_FD004.txt`.
3. Carica i file in ADLS Gen2 o Blob Storage.
4. Registra i file come **Azure ML data asset**.
5. Applica la stessa normalizzazione a train, validation e test.

Per un RUL industriale è importante salvare insieme ai dati:
- scaler o normalizer usato;
- finestratura temporale;
- feature engineering;
- mapping sensori → input tensor del modello.

## 5. Strategia di split

Per `train_FD004`:
- separa gli engine in train e validation;
- evita di spezzare la sequenza di uno stesso engine tra train e validation in modo incoerente;
- usa gli ultimi cicli di una parte degli engine come validation set.

Per `test_FD004`:
- tienilo isolato fino alla valutazione finale.

Obiettivo:
- train = apprendimento;
- validation = scelta del modello;
- test = misura finale imparziale.

## 6. Struttura del progetto

Una struttura minima può essere questa:

```text
src/
  train.py
  evaluate.py
  preprocess.py
  score.py
environment/
  conda.yml
azureml/
  train-job.yml
  endpoint.yml
  deployment.yml
```

## 7. Training del modello

### 7.1 Cosa fa il job di training

Il job deve:
- leggere `train_FD004`;
- costruire finestre temporali sui cicli motore;
- addestrare il CNN-LSTM;
- misurare le metriche su validation;
- salvare il modello finale e gli artefatti di preprocessing;
- loggare metriche e parametri in MLflow.

### 7.2 Dove eseguirlo

Esegui il training su un **Azure ML Compute Cluster** con GPU se il modello è pesante, oppure CPU se il dataset e la rete restano piccoli.

### 7.3 Output atteso

Il training deve produrre:
- modello serializzato
- scaler/preprocessor
- metriche di validation
- grafici di errore o residui
- esempi di predizione vs RUL reale

## 8. Esempio di job Azure ML

Puoi avviare il training con un command job Azure ML.

```yaml
$schema: https://azuremlschemas.azureedge.net/latest/commandJob.schema.json
code: ../src
command: >
  python train.py
  --train_data ${{inputs.train_data}}
  --model_output ${{outputs.model_output}}
environment: azureml:rul-cnnlstm-env@latest
compute: azureml:cpu-cluster
inputs:
  train_data:
    type: uri_folder
    path: azureml://datastores/workspaceblobstore/paths/cmapss/FD004/train/
outputs:
  model_output:
    type: uri_folder
```

Se vuoi usare GPU, cambia `compute` con un cluster GPU e verifica che la libreria PyTorch sia compatibile.

## 9. Valutazione del modello

Dopo il training:
1. esegui `evaluate.py` sul validation set;
2. poi esegui una valutazione finale su `test_FD004`;
3. confronta metriche come RMSE, MAE e scoring RUL-specifico;
4. registra il modello solo se supera la soglia minima concordata.

Per questo caso, una soglia ragionevole va definita in base al baseline CatBoost e al costo operativo di un falso negativo su AOG.

## 10. Registrazione del modello

Quando il modello è valido:
- registralo nel **Azure ML registry**;
- versiona anche preprocessing e feature schema;
- conserva una traccia dell'esperimento in MLflow.

Registra sempre insieme:
- modello;
- scaler;
- config di input;
- metadati del dataset usato.

## 11. Deploy su Azure ML Online Endpoint

### 11.1 Cosa deve fare l'endpoint

L'endpoint riceve telemetria fresca del motore e restituisce:
- RUL stimato;
- rischio di guasto in una finestra temporale;
- eventualmente una classe di priorità operativa.

### 11.2 Deployment consigliato

Usa un **managed online endpoint** con due deployment:
- **blue** = versione corrente stabile;
- **green** = nuova versione candidata.

All'inizio manda il traffico al deployment blue. Poi sposta progressivamente il traffico sul green solo dopo i controlli.

### 11.3 Esempio di endpoint

```yaml
$schema: https://azuremlschemas.azureedge.net/latest/managedOnlineEndpoint.schema.json
name: rul-cnnlstm-endpoint
auth_mode: aad_token
```

```yaml
$schema: https://azuremlschemas.azureedge.net/latest/managedOnlineDeployment.schema.json
name: blue
endpoint_name: rul-cnnlstm-endpoint
model: azureml:rul-cnnlstm-model@latest
code_configuration:
  code: ../src
  scoring_script: score.py
environment: azureml:rul-cnnlstm-env@latest
instance_type: Standard_DS3_v2
instance_count: 1
```

## 12. Logica di scoring

Lo script `score.py` deve:
- caricare modello e scaler;
- trasformare l'input nel formato atteso;
- eseguire l'inferenza;
- restituire RUL e rischio associato.

L'input in produzione deve essere coerente con il preprocessing usato in training. Se la finestratura o la normalizzazione cambiano, il modello diventa inattendibile.

## 13. Monitoring e alert

Per evitare regressioni operative monitora:
- latenza endpoint;
- error rate;
- distribuzione delle feature;
- drift rispetto al training set;
- qualità predittiva su campioni etichettati quando disponibili.

Failure mode da coprire:
- drift dei sensori;
- feature mancanti;
- input fuori distribuzione;
- degrado del modello dopo il deploy;
- latenza troppo alta per uso operativo.

## 14. Rollback

Non fare mai un cutover totale senza rollback.

Regola pratica:
- mantieni il deployment blue attivo;
- sposta il traffico al green in modo graduale;
- se metriche o drift peggiorano, torna subito al blue.

## 15. Sequenza operativa finale

1. Scarica C-MAPSS.
2. Estrai `train_FD004` e `test_FD004`.
3. Carica i dati in ADLS o Blob.
4. Registra i dati come Azure ML data asset.
5. Lancia il training del CNN-LSTM su `train_FD004`.
6. Usa validation per tuning.
7. Valuta il modello su `test_FD004` solo offline.
8. Registra il modello nel registry.
9. Pubblica un online endpoint con deployment blue.
10. Esegui smoke test e shadow test.
11. Sposta il traffico sul green solo se i risultati sono buoni.
12. Monitora drift, error rate e latenza.

## 16. Scelta pratica consigliata

Per questo assignment il percorso più semplice e robusto è:
- preprocessing in Python o Databricks;
- training con Azure ML command job;
- tracking con MLflow;
- deploy su Azure ML Online Endpoint;
- monitoring con Application Insights e Log Analytics.

Se vuoi mantenere il stack molto semplice, puoi anche partire da CPU e passare a GPU solo quando il modello o il volume dati lo richiedono.