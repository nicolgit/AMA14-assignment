# Training CNN-LSTM RUL su Azure ML (step by step)

Questa guida assume che l'infrastruttura sia gia deployata con i template Bicep del repository:
- Resource Group
- Data Lake (ADLS Gen2)
- Azure ML Workspace
- Compute cluster AML (`cpu-cluster`)

Obiettivo: addestrare un modello CNN-LSTM per RUL usando C-MAPSS FD004 (`train_FD004` / `test_FD004`).

## 1) Prerequisiti

1. Azure CLI aggiornata.
2. Estensione Azure ML per CLI:

```powershell
az extension add -n ml -y
az extension update -n ml
```

3. Permessi RBAC minimi:
- Su workspace AML: Contributor (o ruolo equivalente ML)
- Su ADLS: Storage Blob Data Contributor

4. File disponibili in locale:
- `train_FD004.txt`
- `test_FD004.txt`

## 2) Recupera i nomi risorse dal deployment

Se hai usato `az deployment sub create`, recupera output principali:

```powershell
$depName = '<NOME_DEPLOYMENT_SUBSCRIPTION>'
az deployment sub show --name $depName --query "properties.outputs" -o jsonc
```

Annota almeno:
- `resourceGroupId` (per ricavare il nome RG)
- `dataLakeAccountName`
- `mlWorkspaceName`

Imposta variabili ambiente di lavoro:

```powershell
$RG = 'ama-mro-playground'
$WS = 'mlw-ama14mrodev04'
$LAKE = 'lakeama14mrodev04'
```

## 3) Carica train e test nel Data Lake (manuale)

Con ADLS Gen2 e key auth disabilitata, usa AAD (`--auth-mode login`):

```powershell
az storage fs directory create `
  --account-name $LAKE `
  --file-system raw `
  --name "cmapss/fd004/train" `
  --auth-mode login

az storage fs directory create `
  --account-name $LAKE `
  --file-system raw `
  --name "cmapss/fd004/test" `
  --auth-mode login

az storage fs file upload `
  --account-name $LAKE `
  --file-system raw `
  --path "cmapss/fd004/train/train_FD004.txt" `
  --source ".\data\train_FD004.txt" `
  --auth-mode login `
  --overwrite true

az storage fs file upload `
  --account-name $LAKE `
  --file-system raw `
  --path "cmapss/fd004/test/test_FD004.txt" `
  --source ".\data\test_FD004.txt" `
  --auth-mode login `
  --overwrite true
```

## 4) Definisci i Data Asset in Azure ML

Crea due data asset versionati (train/test):

[training yaml](../azureml/train_fd004.yml)

[testing yaml](../azureml/test_fd004.yml)

Registra gli asset:

```powershell
az ml data create -f ../azureml/train_fd004.yml -g $RG -w $WS
az ml data create -f ../azureml/test_fd004.yml -g $RG -w $WS
```

## 5) Crea environment per training

`azureml\environment\rul-cnnlstm-env.yml`

```yaml
$schema: https://azuremlschemas.azureedge.net/latest/environment.schema.json
name: rul-cnnlstm-env
version: 1
image: mcr.microsoft.com/azureml/openmpi4.1.0-ubuntu22.04:latest
conda_file: ./environment/conda.yml
```

`environment/conda.yml`

```yaml
name: rul-cnnlstm
channels:
  - conda-forge
dependencies:
  - python=3.10
  - pip
  - pip:
      - torch
      - numpy
      - pandas
      - scikit-learn
      - mlflow
```

Registra environment:

```powershell
az ml environment create -f .\azureml\environment\rul-cnnlstm-env.yml -g $RG -w $WS
```

## 6) Prepara script di training

Struttura minima:

```text
src/
  train.py
  evaluate.py
  preprocess.py
```

Responsabilita minime di `train.py`:
- legge il train asset
- crea split train/validation per engine-id
- applica preprocessing coerente
- addestra CNN-LSTM
- salva modello + scaler
- logga metriche in MLflow

## 7) Definisci job AML

`azureml/jobs/train_rul_fd004.yml`

```yaml
$schema: https://azuremlschemas.azureedge.net/latest/commandJob.schema.json
display_name: train-rul-cnnlstm-fd004
experiment_name: rul-fd004
code: ../../src
command: >-
  python train.py
  --train_data ${{inputs.train_data}}
  --model_output ${{outputs.model_output}}
inputs:
  train_data:
    type: uri_file
    path: azureml:train-fd004:1
outputs:
  model_output:
    type: uri_folder
environment: azureml:rul-cnnlstm-env:1
compute: azureml:cpu-cluster
```

Lancia il training:

```powershell
az ml job create -f .\azureml\jobs\train_rul_fd004.yml -g $RG -w $WS
```

## 8) Monitora il job e leggi metriche

```powershell
az ml job list -g $RG -w $WS --query "[?contains(display_name,'train-rul-cnnlstm-fd004')].[name,status]" -o table

$jobName = '<JOB_NAME>'
az ml job show -n $jobName -g $RG -w $WS -o jsonc
az ml job stream -n $jobName -g $RG -w $WS
```

Metriche target consigliate:
- MAE
- RMSE
- errore sui casi a basso RUL (piu critici operativamente)

## 9) Valuta su test_FD004 (offline)

Best practice:
- non usare mai `test_FD004` durante training/tuning
- usa `test_FD004` solo per validazione finale

Puoi farlo con job dedicato `evaluate.py` o nello stesso pipeline step successivo.

## 10) Registra il modello in Azure ML

Dopo test finale positivo:

```powershell
az ml model create `
  --name rul-cnnlstm-fd004 `
  --version 1 `
  --path azureml://jobs/<JOB_NAME>/outputs/model_output `
  -g $RG -w $WS
```

## 11) Checklist prima del deploy endpoint

1. Modello registrato e versionato
2. Artefatti preprocessing registrati insieme al modello
3. Metriche documentate (validation + test)
4. Contratto input/output dello scoring stabile
5. Piano rollback versione precedente

## 12) Errori comuni e fix rapidi

- `AuthorizationFailure` su Data Lake:
  assegna `Storage Blob Data Contributor` e aspetta propagation RBAC.

- Job AML non parte su compute:
  verifica stato `cpu-cluster` e quota region.

- Differenze train vs test molto alte:
  controlla leakage, split per engine-id, e coerenza preprocessing.
