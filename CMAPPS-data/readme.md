Data Set: FD001
Train trjectories: 100
Test trajectories: 100
Conditions: ONE (Sea Level)
Fault Modes: ONE (HPC Degradation)

Data Set: FD002
Train trjectories: 260
Test trajectories: 259
Conditions: SIX 
Fault Modes: ONE (HPC Degradation)

Data Set: FD003
Train trjectories: 100
Test trajectories: 100
Conditions: ONE (Sea Level)
Fault Modes: TWO (HPC Degradation, Fan Degradation)

Data Set: FD004
Train trjectories: 248
Test trajectories: 249
Conditions: SIX 
Fault Modes: TWO (HPC Degradation, Fan Degradation)



Experimental Scenario

Data sets consists of multiple multivariate time series. Each data set is further divided into training and test subsets. Each time series is from a different engine � i.e., the data can be considered to be from a fleet of engines of the same type. Each engine starts with different degrees of initial wear and manufacturing variation which is unknown to the user. This wear and variation is considered normal, i.e., it is not considered a fault condition. There are three operational settings that have a substantial effect on engine performance. These settings are also included in the data. The data is contaminated with sensor noise.

The engine is operating normally at the start of each time series, and develops a fault at some point during the series. In the training set, the fault grows in magnitude until system failure. In the test set, the time series ends some time prior to system failure. The objective of the competition is to predict the number of remaining operational cycles before failure in the test set, i.e., the number of operational cycles after the last cycle that the engine will continue to operate. Also provided a vector of true Remaining Useful Life (RUL) values for the test data.

The data are provided as a zip-compressed text file with 26 columns of numbers, separated by spaces. Each row is a snapshot of data taken during a single operational cycle, each column is a different variable. The columns correspond to:
1.	unit number
2.	time, in cycles
3.	operational setting 1
4.	operational setting 2
5.	operational setting 3
6.	sensor measurement  1
7.	sensor measurement  2
...
26.	sensor measurement  26


> Reference: A. Saxena, K. Goebel, D. Simon, and N. Eklund, �Damage Propagation Modeling for Aircraft Engine Run-to-Failure Simulation�, in the Proceedings of the Ist International Conference on Prognostics and Health Management (PHM08), Denver CO, Oct 2008.



## Struttura delle colonne di FD004

Le colonne di FD004 seguono il formato standard C-MAPSS: **26 colonne separate da spazi**, dove ogni riga è uno _snapshot_ di un singolo ciclo operativo di un motore.

### Colonne in `test_FD004.txt` / `train_FD004.txt`

| Colonna | Nome | Significato |
| --- | --- | --- |
| 1 | `unit number` | ID del motore (1, 2, 3, ...). Identifica a quale motore della flotta appartiene la riga. In FD004: 248 motori nel train, 249 nel test. |
| 2 | `time, in cycles` | Numero del ciclo operativo per quel motore. Riparte da 1 per ogni nuovo motore e cresce di 1 a ogni riga (è il "tempo" della serie temporale). |
| 3 | `operational setting 1` | Condizione operativa 1 (es. quota / altitude). |
| 4 | `operational setting 2` | Condizione operativa 2 (es. numero di Mach). |
| 5 | `operational setting 3` | Condizione operativa 3 (es. manetta / throttle resolver angle TRA). |
| 6–26 | `sensor measurement 1...21` | 21 misure dei sensori (temperature, pressioni, velocità di rotazione, rapporti di flusso, ecc.). |

> **Nota:** il readme dice "sensor measurement 1...26", ma di fatto le colonne sono 26 totali, quindi i sensori sono **21** (colonne 6→26). È un refuso classico della documentazione originale NASA.

Layout di una riga:

```text
[unit] [cycle] [op_set1] [op_set2] [op_set3] [s1] [s2] ... [s21]
  1      1      -0.0007    0.0004    100.0    518.67 ...
  ^      ^      └──── condizione operativa ───┘ └─ 21 sensori ─┘
  │      └─ tempo (ciclo)
  └─ ID motore
```

### Punti chiave specifici di FD004

- **ID motore** → colonna `1`.
- **Condizione operativa** → colonne `3`, `4`, `5` (le tre `operational setting`). In FD004 ci sono **6 regimi operativi distinti** (`CONDITIONS: SIX`): combinando i valori di queste 3 colonne i punti si raggruppano in 6 cluster. Per questo in fase di preprocessing è quasi obbligatorio **normalizzare i sensori per regime operativo** (clustering sulle colonne 3-5), altrimenti il segnale di degrado è mascherato dalle variazioni di condizione.
- **Modalità di guasto** → **NON è una colonna esplicita**. È una proprietà del dataset, non un campo nei dati:
  - FD004 ha **2 fault mode**: degrado HPC (High Pressure Compressor) + degrado della ventola (Fan).
  - Quale dei due (o entrambi) affligga un dato motore è **latente/sconosciuto**: deve emergere dal pattern dei sensori, non è etichettato.
