# Algoritmo di urgenza manutenzione preventiva (RUL)

## Obiettivo

Dato un valore di **RUL predetto** (Remaining Useful Life) per un motore e le metriche di qualità del modello (**MAE** e **RMSE**), classificare l'urgenza della manutenzione preventiva su tre livelli:

- **Verde**: non serve ancora fare nulla
- **Giallo**: siamo vicini alla soglia
- **Rosso**: pianificare intervento

L'idea è trasformare una stima puntuale (RUL) in una decisione robusta, incorporando l'incertezza del modello.

## Dati in input

- `RUL` predetto per motore (tabella `prediction`)
- `MAE` globale modello (tabella `evaluation`)
- `RMSE` globale modello (tabella `evaluation`)
- `H` orizzonte operativo in cicli (finestra decisionale, es. 30)

Con i valori correnti del progetto:

- `MAE = 25.857178447708005`
- `RMSE = 34.41467739840854`

## Razionale statistico

### 1) Correzione conservativa del RUL

Per evitare ottimismo nella stima, correggiamo il RUL predetto sottraendo il MAE:

$$
\mu_c = RUL - MAE
$$

Dove $\mu_c$ rappresenta una stima prudente della vita residua.

### 2) Incertezza della stima

Usiamo l'RMSE come deviazione standard approssimata:

$$
\sigma = RMSE
$$

### 3) Probabilità di rischio entro l'orizzonte H

Stimiamo la probabilità che il RUL reale sia già sotto la soglia operativa entro $H$ cicli:

$$
p_{risk} = P(RUL_{reale} \le H)
$$

Assumendo un errore circa normale:

$$
p_{risk} = \Phi\left(\frac{H-\mu_c}{\sigma}\right)
= \Phi\left(\frac{H + MAE - RUL}{RMSE}\right)
$$

Dove $\Phi$ è la CDF della normale standard.

### 4) Cosa significa CDF e come si calcola

**CDF** significa **Cumulative Distribution Function** (funzione di distribuzione cumulativa).

Per una variabile casuale $X$, la CDF è:

$$
F(x) = P(X \le x)
$$

Interpretazione: restituisce la probabilita che $X$ sia minore o uguale a una soglia $x$.

Nel nostro caso usiamo $\Phi(z)$, cioe la CDF della normale standard:

$$
\Phi(z) = \frac{1}{\sqrt{2\pi}}\int_{-\infty}^{z} e^{-t^2/2}\,dt
$$

Questa integrale non ha una forma elementare semplice, quindi in pratica si usa:

- una tabella Z
- una funzione software (es. `scipy.stats.norm.cdf`)
- oppure la funzione errore:

$$
\Phi(z)=\frac{1}{2}\left(1+\operatorname{erf}\left(\frac{z}{\sqrt{2}}\right)\right)
$$

Applicazione al nostro algoritmo:

$$
z = \frac{H + MAE - RUL}{RMSE}
$$

$$
p_{risk} = \Phi(z)
$$

Dunque la CDF trasforma il punteggio normalizzato $z$ in una probabilita di rischio direttamente interpretabile (da 0 a 1).

## Regole decisionali a tre livelli

Soglie proposte iniziali:

- **Verde** se $p_{risk} < 0.30$
- **Giallo** se $0.30 \le p_{risk} < 0.60$
- **Rosso** se $p_{risk} \ge 0.60$

Interpretazione operativa:

- **Verde**: rischio basso nel breve termine
- **Giallo**: rischio intermedio, monitoraggio stretto e pre-pianificazione
- **Rosso**: rischio alto, pianificare manutenzione preventiva

## Esempio numerico (H = 30)

Con `MAE=25.86` e `RMSE=34.41`:

- soglia indicativa **rosso** circa per `RUL <= 47.1`
- soglia indicativa **giallo** circa per `47.1 < RUL <= 73.9`
- **verde** oltre `73.9`

Nota: queste soglie equivalenti in RUL dipendono da `H`, MAE, RMSE e dai cut-off probabilistici scelti (0.30/0.60).

## Pseudocodice

```text
input: rul, mae, rmse, horizon_cycles=30

mu_c = rul - mae
z = (horizon_cycles - mu_c) / rmse
p_risk = normal_cdf(z)

if p_risk >= 0.60:
    level = "red"
elif p_risk >= 0.30:
    level = "yellow"
else:
    level = "green"

return level, p_risk
```

## Contratto API implementato

Endpoint disponibili:

- `POST /v1/maintenance/urgency`
- `GET /v1/maintenance/urgency/engines`

### 1) POST /v1/maintenance/urgency

Validazioni input implementate:

- `rul >= 0`
- `horizon_cycles > 0` (default `30`)

Request:

```json
{
  "rul": 42.0,
  "horizon_cycles": 30
}
```

Response:

```json
{
  "level": "red",
  "risk_probability": 0.72,
  "explanation": "Rischio alto: pianificare intervento di manutenzione preventiva.",
  "inputs": {
    "rul": 42.0,
    "horizon_cycles": 30,
    "mae": 25.857178447708005,
    "rmse": 34.41467739840854
  },
  "thresholds": {
    "yellow_from": 0.30,
    "red_from": 0.60
  }
}
```

Nota: in implementazione `risk_probability` viene arrotondato a 6 decimali.

### 2) GET /v1/maintenance/urgency/engines

Query parameter:

- `horizon_cycles` opzionale, default `30`, deve essere `> 0`

Response esempio:

```json
[
  {
    "engine_id": 1,
    "predicted_rul": 18.4,
    "level": "red",
    "risk_probability": 0.834512,
    "explanation": "Rischio alto: pianificare intervento di manutenzione preventiva."
  },
  {
    "engine_id": 2,
    "predicted_rul": 36.9,
    "level": "yellow",
    "risk_probability": 0.451203,
    "explanation": "Rischio intermedio: vicini alla soglia, aumentare monitoraggio."
  },
  {
    "engine_id": 3,
    "predicted_rul": 79.2,
    "level": "green",
    "risk_probability": 0.083114,
    "explanation": "Rischio basso: non e necessario intervenire ora."
  }
]
```

## Parametri da governare

Per passare in produzione, conviene rendere configurabili:

- `H` (orizzonte operativo)
- soglie probabilistiche (`0.30`, `0.60`)
- metriche (`MAE`, `RMSE`) per versione modello

## Come approcciare il calcolo di H (orizzonte operativo)

`H` non e un parametro "matematico puro": e una scelta operativa che dipende dal tempo necessario per organizzare la manutenzione.

### 1) Stima iniziale basata sui lead time

Definire un primo valore di lavoro:

$$
H_{iniziale} \approx LT_{ricambi} + LT_{planning} + LT_{officina} + buffer_{sicurezza}
$$

Dove ogni termine e espresso nella stessa unita del RUL (cicli/ore/voli).

### 2) Validazione su storico (backtest)

Valutare una griglia di candidati, ad esempio `H in {20, 30, 40}`:

- quanti casi critici vengono intercettati in tempo (copertura)
- quanto anticipo medio si ottiene prima della soglia reale
- quante segnalazioni portano a manutenzione troppo anticipata

L'obiettivo e trovare il miglior compromesso tra rischio operativo e costo di over-maintenance.

### 3) Criterio economico-operativo

Formalmente si puo scegliere `H` minimizzando un costo atteso:

$$
Costo(H) = C_{late}\cdot P(intervento\ tardivo) + C_{early}\cdot P(intervento\ anticipato)
$$

In contesti safety-critical, tipicamente $C_{late} \gg C_{early}$, quindi conviene privilegiare la riduzione dei ritardi anche a costo di qualche intervento anticipato.

### 4) Regola pratica di adozione

- partire da `H = H_iniziale`
- monitorare KPI per 2-4 settimane
- correggere `H` con piccoli step (es. +/- 5 cicli)

In assenza di storico robusto, `H = 30` e una baseline ragionevole per iniziare, ma va sempre ricalibrata su dati operativi reali.

## Limiti e miglioramenti futuri

- MAE e RMSE globali non catturano differenze per regime operativo o famiglia motore.
- L'ipotesi normale è pratica ma approssimata.
- Possibile evoluzione: soglie per classe motore/flotta e calibrazione periodica su storico manutenzioni reali.
