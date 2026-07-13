# Spare Optimization Supply (RUL + geolocalizzazione)

## 1) Obiettivo operativo

Per ogni richiesta di manutenzione, scegliere la fonte del ricambio tra:

1. stock locale nella location dell'aereo;
2. trasferimento da un'altra location;
3. ordine a fornitore.

La scelta deve minimizzare costo e rischio di fermo, usando insieme:

- disponibilita geolocalizzata dei ricambi;
- RUL motore (in cicli);
- rischio di rottura entro 30 cicli.


## 2) Input minimi

Per ogni aereo i:

- `aircraft_id`
- `location_id` (location dove avverra la riparazione)
- `rul_cycles` (RUL residuo in cicli)
- `risk_30` (probabilita di guasto entro 30 cicli, range 0..1)

Per ogni ricambio p e location l:

- `p` = codice ricambio (part number)
- `l` = location generica

- `on_hand[l,p]` (quantita disponibile)
- `reserved[l,p]` (quantita gia impegnata)
- `min_stock[l,p]` (soglia minima non violabile)

Per ogni coppia location origine/destinazione:

- `o` = location di origine (donatrice)
- `d` = location di destinazione (dove serve il ricambio)

- `transfer_time_cycles[o,d]`
- `transfer_cost[o,d,p]`

Per ordine fornitore:

- `supplier_lead_time_cycles[d,p]`
- `supplier_cost[d,p]`


## 3) Urgenza tecnica

Definiamo un indice unico di urgenza:

> serve a trasformare due segnali diversi in un solo numero che indica quanto è urgente la riparazione (risk_30 pesa il 60%, rul cicle pesa per il 40%)

$$
u_i = 0.6 * risk\_30_i + 0.4 * \left(1 - \frac{\min(rul_i, 30)}{30}\right)
$$

Finestra utile (in cicli) prima dell'evento critico:

> Significa: quanti cicli “utili” hai prima del punto critico, con tetto a 30 cicli.

$$
T_i = \min(rul_i, 30)
$$

Buffer di sicurezza consigliato:
> Significa: una quota della finestra utile che tieni da parte come margine contro imprevisti (errore modello, ritardi logistici, variabilità operativa). È almeno 1 ciclo, altrimenti vale il 20% della finestra utile.

$$
buffer_i = \max(1.0, 0.2 * T_i)
$$

Tempo massimo accettabile per avere il ricambio:

$$
deadline_i = T_i - buffer_i
$$


## 4) Classi priorita (MVP)

- ROSSO: `risk_30 >= 0.60` oppure `rul_cycles <= 10`
- GIALLO: `0.30 <= risk_30 < 0.60` oppure `10 < rul_cycles <= 20`
- VERDE: tutti gli altri casi

Service level target:

- ROSSO: copertura entro 3 cicli
- GIALLO: copertura entro 10 cicli
- VERDE: copertura entro 20 cicli


## 5) Vincoli di fattibilita

Una opzione e fattibile se:

1. disponibilita effettiva > 0

$$
available[l,p] = on\_hand[l,p] - reserved[l,p]
$$

2. tempo di arrivo entro la finestra:

$$
eta\_cycles\_option \le deadline_i
$$

3. per trasferimenti: la location donatrice non deve scendere sotto `min_stock`:

$$
on\_hand[o,p] - 1 \ge min\_stock[o,p]
$$


## 6) Funzione di scelta
La funzione di scelta è una funzione di scoring progettata per tradurre l’obiettivo operativo del problema in una regola decisionale semplice, ovvero scegliere tra stock locale, trasferimento o ordine a fornitore minimizzando insieme:

- costo;
- rischio di ritardo;
- rischio di impoverire troppo una base donatrice.

Per ogni opzione fattibile calcoliamo:

$$
score = cost + delay\_penalty + stock\_penalty
$$

dove:

$$
delay\_penalty = \lambda * u_i * \max(0, eta\_option - deadline_i)
$$

$$
stock\_penalty = \mu * donor\_scarcity
$$

Parametri iniziali suggeriti:

- `lambda = 500`
- `mu = 50`

La policy sceglie l'opzione con score minimo. Se nessuna opzione e fattibile, trigger di escalation.


## 7) Matrice decisionale semplice

1. Se stock locale disponibile e `eta_local = 0 <= deadline`: usa locale.
2. Altrimenti valuta trasferimenti da tutte le location donatrici fattibili.
3. Valuta ordine fornitore.
4. Se esiste almeno una opzione in deadline: scegli score minimo.
5. Se nessuna opzione in deadline:
   - ROSSO: escalation immediata (AOG prevention), puo violare min_stock donor con approvazione.
   - GIALLO/VERDE: scegli min costo con min ritardo e apri alert pianificazione.


## 8) Pseudocodice

```text
for each maintenance_request r:
	i = aircraft(r)
	p = required_part(r)
	d = location(i)

	compute u_i, T_i, buffer_i, deadline_i

	options = []

	# A) local
	if available[d,p] >= 1:
		options.append({type: "local", eta: 0, cost: local_handling_cost})

	# B) transfer
	for each origin o != d:
		if available[o,p] >= 1 and (on_hand[o,p] - 1 >= min_stock[o,p]):
			options.append({
				type: "transfer",
				origin: o,
				eta: transfer_time_cycles[o,d],
				cost: transfer_cost[o,d,p],
				donor_scarcity: max(0, min_stock[o,p] - (on_hand[o,p]-1))
			})

	# C) supplier
	options.append({
		type: "order",
		eta: supplier_lead_time_cycles[d,p],
		cost: supplier_cost[d,p],
		donor_scarcity: 0
	})

	feasible = [x for x in options if x.eta <= deadline_i]

	if feasible not empty:
		choose argmin score(x)
	else:
		choose emergency policy by priority class
```


## 9) Output atteso per API/UI

Per ogni richiesta:

- `decision`: `local | transfer | order | emergency`
- `selected_origin` (se transfer)
- `eta_cycles`
- `total_cost`
- `urgency_score`
- `priority_class`
- `reason_codes` (es. `NO_LOCAL_STOCK`, `FASTEST_FEASIBLE`, `CHEAPEST_IN_DEADLINE`, `ESCALATION_RED`)


## 10) KPI da monitorare

1. `on_time_coverage_rate`: % richieste soddisfatte entro deadline.
2. `stockout_rate_by_location`: stockout per location e part.
3. `aog_prevented`: interventi ROSSI coperti prima evento critico.
4. `mean_logistic_response_cycles`: tempo medio logistico.
5. `total_spare_logistics_cost`: costo totale (transfer + order + handling).


## 11) Calibrazione iniziale (pragmatica)

1. Eseguire simulazione su storico ultimi 3-6 mesi.
2. Grid search su `lambda`, `mu`, soglie ROSSO/GIALLO.
3. Selezionare set che minimizza AOG attesi con incremento costo accettabile.
4. Congelare policy per 2 settimane e monitorare drift.


## 12) Prossimo passo tecnico consigliato

Implementare un endpoint di raccomandazione, ad esempio:

- `POST /v1/supply/decision`

con payload manutenzione + part list e risposta con ranking opzioni (`top_k`) e motivazione.
