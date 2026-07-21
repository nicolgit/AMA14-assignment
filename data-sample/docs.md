# docs — descrizione delle colonne

questo file documenta lo schema di [docs.csv](docs.csv), l'elenco dei metadata dei documenti tecnici manutentivi presenti sul Data Lake (container `engineering-docs`, path `sample-docs/`).

il contenuto dei documenti resta sul blob storage; questa tabella fornisce i metadata che lo strato API userà per mostrare l'elenco documenti della Knowledge Base EASA.

## colonne

| Colonna | Tipo | Esempio | Significato |
|---|---|---|---|
| `document_id` | string | `TC-0001` | chiave primaria: identificativo del documento |
| `title` | string | `HPC Borescope Inspection (Routine)` | titolo descrittivo del documento |
| `type` | enum | `Task Card` | tipo documento: `AMM`, `SRM`, `CMM`, `AD`, `SB`, `Task Card` |
| `revision` | string | `Rev. 14` | revisione del documento |
| `date` | date (ISO `YYYY-MM-DD`) | `2026-05-10` | data di revisione / emissione |
| `storage_uri` | string | `engineering-docs/sample-docs/task-card-0001.md` | URI relativa nello storage account (`<container>/<path>/<file>`) |
| `status` | enum | `published` | stato editoriale: `draft`, `published` |

## note

* `storage_uri` è coerente con l'upload eseguito da [populate-maintenance-data.ps1](../powershell/populate-maintenance-data.ps1): container `engineering-docs`, path `sample-docs/`.
* tutti i documenti del PoC sono in stato `published`; lo stato `draft` è previsto per bozze non ancora approvate dal review workflow ingegneristico.
* la tabella `document` viene creata e popolata su PostgreSQL da [populate-sql.ps1](../powershell/populate-sql.ps1) leggendo `docs.csv`.
