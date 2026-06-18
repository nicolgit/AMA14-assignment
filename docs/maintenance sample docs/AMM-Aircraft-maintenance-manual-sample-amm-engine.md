# Aircraft Maintenance Manual (AMM) — Sample Extract (Synthetic / PoC Only)

> **DISCLAIMER — NOT APPROVED DATA.** This document is a **synthetic, fictional** AMM extract created solely to develop and test a Proof of Concept (RAG / Gen AI assistant). It is **NOT approved maintenance data**, must **never** be used on a real aircraft or component, and does not represent any real OEM publication. All values, limits, part numbers and task references are invented.

---

## Document control

| Field | Value |
|-------|-------|
| Manual | AMM — Powerplant (synthetic) |
| Aircraft type | Generic twin-turbofan (PoC) |
| Engine model | GEN-TF-100 (fictional high-bypass turbofan) |
| Manual revision | Rev. 14 |
| Revision date | 2026-05-01 |
| ATA chapters covered | 70–80 (Powerplant) |
| Effectivity baseline | MSN 0001–0420, pre-mod and post-mod where stated |
| Source format note | Authored to mimic ATA iSpec 2200 task numbering for RAG ingestion |

**Effectivity legend**
- `ALL` = applicable to all MSN in the baseline range.
- `PRE-MOD xxxx` = applicable before Service Bulletin xxxx is embodied.
- `POST-MOD xxxx` = applicable after Service Bulletin xxxx is embodied.

**Acronyms:** AMM (Aircraft Maintenance Manual), MSN (Manufacturer Serial Number), AD (Airworthiness Directive), SB (Service Bulletin), CRS (Certificate of Release to Service), HPC (High Pressure Compressor), LPT (Low Pressure Turbine), EGT (Exhaust Gas Temperature), N1 (fan/LP spool speed), N2 (core/HP spool speed), BSI (Borescope Inspection).

---

## Procedure index

| Task | ATA | Title | Effectivity | Revision |
|------|-----|-------|-------------|----------|
| 72-00-00-200-001 | 72 | HPC Borescope Inspection | ALL | Rev. 14 |
| 72-30-00-300-002 | 72 | HPC Blade Blending Repair (within limits) | POST-MOD 7204 | Rev. 13 |
| 72-50-00-200-003 | 72 | LPT Performance Trend Check | ALL | Rev. 12 |
| 73-21-00-400-004 | 73 | Fuel Nozzle Removal / Installation | ALL | Rev. 14 |
| 75-30-00-200-005 | 75 | HPC Bleed Valve Functional Test | PRE-MOD 7510 | Rev. 11 |
| 77-21-00-700-006 | 77 | EGT Indication System Test | ALL | Rev. 14 |
| 79-21-00-600-007 | 79 | Engine Oil Filter Inspection (chip detection) | ALL | Rev. 14 |
| 79-30-00-200-008 | 79 | Engine Oil Consumption Trend Check | ALL | Rev. 13 |
| 70-00-00-100-009 | 70 | Engine Dry Motoring (cool-down / clearing) | ALL | Rev. 14 |
| 71-00-00-800-010 | 71 | Fan Blade Visual Inspection (FOD assessment) | ALL | Rev. 14 |

---

## Task 72-00-00-200-001 — HPC Borescope Inspection

- **ATA:** 72-00-00
- **Effectivity:** ALL (MSN 0001–0420)
- **Revision:** Rev. 14 (2026-05-01)
- **Task type:** Scheduled / on-condition inspection
- **Related data:** MPD task 72-BSI-2000; AD 2025-08-03; SB 7204
- **Trigger:** EGT margin trend degradation, N2 vibration alert, or every 2,000 engine cycles.

**Tooling**
- Video borescope, 6 mm articulating probe.
- Engine turning tool, P/N GEN-TT-072.

**Safety**
- **WARNING:** Ensure engine has cooled below 60 °C before probe insertion. Hot section contact causes burns.
- **CAUTION:** Do not rotate the spool against the borescope probe direction; blade tip damage may occur.

**Procedure**
1. Open the HPC borescope access ports 3 through 7.
2. Insert the probe at stage 4 inlet.
3. Rotate N2 spool manually using the turning tool; inspect each blade leading edge.
4. Record any cracking, tip curl, coating loss, or burning.
5. Assess findings against limits below.

**Limits / acceptance**
- Coating loss: acceptable up to 15% of airfoil surface per blade.
- Leading-edge nicks: acceptable up to 0.8 mm depth; above this → see Task 72-30-00-300-002.
- Any crack: **reject** → raise non-routine card; refer to engineering disposition.

**Sign-off:** Inspection result recorded on work order; CRS by certifying staff.

---

## Task 72-30-00-300-002 — HPC Blade Blending Repair (within limits)

- **ATA:** 72-30-00
- **Effectivity:** POST-MOD 7204 only
- **Revision:** Rev. 13 (2025-11-15)
- **Task type:** Repair (within approved limits)
- **Related data:** Task 72-00-00-200-001; SB 7204; SRM 72-30 fig. 4

**Tooling**
- Approved hand blending kit GEN-BLEND-72.
- Surface finish comparator, Ra ≤ 0.8 µm.

**Safety**
- **CAUTION:** Blending outside the limits below is **not approved** by this task. Out-of-limit damage requires OEM/DOA repair approval.

**Procedure**
1. Confirm SB 7204 is embodied on this engine (POST-MOD). If PRE-MOD, this task does **not** apply.
2. Identify damaged blade and stage from the BSI record.
3. Blend the nick/dent following a smooth radius; do not create sharp transitions.
4. Restore surface finish to Ra ≤ 0.8 µm.
5. Re-inspect blended area by borescope.

**Limits / acceptance**
- Max blend depth: 1.2 mm.
- Max blended length: 12 mm per blade, leading edge only.
- Max 2 blades blended per stage.
- Exceedance of any limit → **stop**, raise non-routine card, request OEM/DOA disposition.

**Sign-off:** Repair recorded with before/after images; CRS by certifying staff.

---

## Task 72-50-00-200-003 — LPT Performance Trend Check

- **ATA:** 72-50-00
- **Effectivity:** ALL
- **Revision:** Rev. 12 (2025-09-10)
- **Task type:** Performance monitoring
- **Related data:** Task 77-21-00-700-006; MPD 72-TREND-5000

**Procedure**
1. Download last 50 flight cycles of EGT, N1, N2, fuel flow.
2. Normalize to reference ambient conditions.
3. Plot EGT margin trend.
4. Compare degradation slope to baseline fleet curve.

**Limits / acceptance**
- EGT margin loss > 12 °C over 100 cycles → schedule BSI (Task 72-00-00-200-001).
- EGT margin below 20 °C → flag for shop visit planning.

**Sign-off:** Trend report attached to engine record.

---

## Task 73-21-00-400-004 — Fuel Nozzle Removal / Installation

- **ATA:** 73-21-00
- **Effectivity:** ALL
- **Revision:** Rev. 14 (2026-05-01)
- **Task type:** Component removal / installation
- **Related data:** CMM 73-21; torque table 73-T1

**Tooling**
- Nozzle socket GEN-NS-73.
- Calibrated torque wrench, range 8–25 Nm.

**Safety**
- **WARNING:** Depressurize and drain the fuel manifold before removal. Residual fuel is flammable.
- **CAUTION:** Use new seals on installation. Do not reuse copper gaskets.

**Procedure**
1. Isolate and drain the fuel manifold.
2. Disconnect the nozzle fuel line.
3. Remove the nozzle retaining nut with socket GEN-NS-73.
4. Withdraw the nozzle; cap the port.
5. On installation, fit new seals, torque to 18 Nm ± 1 Nm.
6. Perform a leak check at idle.

**Limits / acceptance**
- No fuel leak permitted at the nozzle joint.
- Spray pattern check per CMM 73-21 if nozzle is refitted after cleaning.

**Sign-off:** Leak check result recorded; CRS by certifying staff.

---

## Task 75-30-00-200-005 — HPC Bleed Valve Functional Test

- **ATA:** 75-30-00
- **Effectivity:** PRE-MOD 7510
- **Revision:** Rev. 11 (2025-06-20)
- **Task type:** Functional test
- **Related data:** SB 7510 (supersedes this test POST-MOD)

**Safety**
- **CAUTION:** POST-MOD 7510 engines use an electronic bleed valve; this manual test does **not** apply. Use Task 75-30-00-200-015 instead (not in this extract).

**Procedure**
1. Confirm SB 7510 is **not** embodied (PRE-MOD).
2. Apply control air pressure to the bleed valve actuator.
3. Verify valve travels full open to full closed.
4. Measure actuation time.

**Limits / acceptance**
- Full stroke actuation time: 1.5–3.0 s.
- Sticking or partial travel → replace bleed valve.

**Sign-off:** Test values recorded on work order.

---

## Task 77-21-00-700-006 — EGT Indication System Test

- **ATA:** 77-21-00
- **Effectivity:** ALL
- **Revision:** Rev. 14 (2026-05-01)
- **Task type:** System test
- **Related data:** Task 72-50-00-200-003; wiring diagram 77-W2

**Procedure**
1. Connect the thermocouple test set to the EGT harness.
2. Inject simulated temperature signals at 400 °C, 600 °C, 800 °C.
3. Compare indicated EGT to injected values.

**Limits / acceptance**
- Indication error: ≤ ±5 °C across the range.
- Error above tolerance → inspect harness and thermocouples per wiring diagram 77-W2.

**Sign-off:** Calibration result recorded.

---

## Task 79-21-00-600-007 — Engine Oil Filter Inspection (chip detection)

- **ATA:** 79-21-00
- **Effectivity:** ALL
- **Revision:** Rev. 14 (2026-05-01)
- **Task type:** Inspection
- **Related data:** Task 79-30-00-200-008; AD 2024-11-07

**Safety**
- **WARNING:** Oil may be hot. Wear protective gloves.

**Procedure**
1. Remove the oil filter element.
2. Inspect the filter and magnetic chip detector for metal particles.
3. Classify particles: fuzz, chips, or flakes.
4. If chips/flakes present, retain sample for analysis.

**Limits / acceptance**
- Light fuzz: acceptable; refit and continue monitoring.
- Visible metallic chips/flakes: **reject** → raise non-routine card, ground engine pending analysis (refer AD 2024-11-07).

**Sign-off:** Findings recorded; CRS by certifying staff.

---

## Task 79-30-00-200-008 — Engine Oil Consumption Trend Check

- **ATA:** 79-30-00
- **Effectivity:** ALL
- **Revision:** Rev. 13 (2025-12-01)
- **Task type:** Trend monitoring
- **Related data:** Task 79-21-00-600-007

**Procedure**
1. Record oil uplift per flight cycle over the last 30 cycles.
2. Compute average consumption (litres per 10 cycles).
3. Compare to engine baseline.

**Limits / acceptance**
- Consumption < 0.5 L/10 cycles: normal.
- 0.5–1.0 L/10 cycles: increase monitoring frequency.
- > 1.0 L/10 cycles: investigate seals/bearings; raise non-routine card.

**Sign-off:** Trend report attached to engine record.

---

## Task 70-00-00-100-009 — Engine Dry Motoring (cool-down / clearing)

- **ATA:** 70-00-00
- **Effectivity:** ALL
- **Revision:** Rev. 14 (2026-05-01)
- **Task type:** Operational procedure
- **Related data:** Engine start checklist 70-CL1

**Safety**
- **WARNING:** Ensure fuel and ignition are OFF during dry motoring to prevent an unintended start.

**Procedure**
1. Set fuel control to OFF and ignition to OFF.
2. Engage the starter to motor the engine.
3. Maintain motoring for the specified duration to clear residual fuel or aid cool-down.
4. Observe N2 rotation and oil pressure rise.

**Limits / acceptance**
- Starter duty cycle: max 90 s ON, then 5 min cool-down.
- No oil pressure within 30 s → stop, investigate.

**Sign-off:** Operation recorded on work order.

---

## Task 71-00-00-800-010 — Fan Blade Visual Inspection (FOD assessment)

- **ATA:** 71-00-00
- **Effectivity:** ALL
- **Revision:** Rev. 14 (2026-05-01)
- **Task type:** Visual inspection
- **Related data:** SRM 71-10 fig. 2; Task 72-00-00-200-001

**Safety**
- **CAUTION:** Do not rotate the fan by pushing on blade tips; push at the root area only.

**Procedure**
1. Inspect each fan blade leading edge for nicks, dents, tears, and FOD (Foreign Object Damage).
2. Measure damage depth with a calibrated gauge.
3. Record blade number and damage location.

**Limits / acceptance**
- Leading-edge nicks ≤ 1.0 mm depth: acceptable, blend per SRM 71-10.
- Nicks 1.0–2.0 mm: engineering disposition required.
- Tears, cracks, or damage > 2.0 mm: **reject** → raise non-routine card, request OEM/DOA repair approval.

**Sign-off:** Inspection result recorded; CRS by certifying staff.

---

## Notes for PoC use

- Each task is **self-contained** and includes structured metadata (ATA, effectivity, revision, related data, limits) — good for chunking and metadata filtering in a RAG index.
- **Effectivity** (`ALL` / `PRE-MOD` / `POST-MOD`) lets you test configuration-aware retrieval (e.g., Task 75-30 must NOT be returned for a POST-MOD 7510 engine).
- **Revision** fields let you test "return only the current revision" logic.
- **Limits / acceptance** sections let you test the three outcome branches: within-limit (apply), out-of-limit (engineering disposition), reject (OEM/DOA approval).
- Engine-centric content (HPC, LPT, fan, oil, EGT) is aligned with the C-MAPSS FD004 RUL scenario used elsewhere in this repo.
