<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '../components/PageHeader.vue'
import EngineListTable from '../components/EngineListTable.vue'
import { API_BASE_URL } from '../config'

interface SupplyPartRequest {
  part_number: string
  quantity: number
  supplier_lead_time_cycles?: number
  supplier_cost?: number
}

interface SupplyOption {
  decision: 'local' | 'transfer' | 'order' | 'emergency'
  selected_origin: string | null
  eta_cycles: number
  total_cost: number
  urgency_score: number
  priority_class: 'RED' | 'YELLOW' | 'GREEN'
  score: number
  feasible: boolean
  reason_codes: string[]
}

interface SupplyPartDecision {
  part_number: string
  quantity: number
  decision: 'local' | 'transfer' | 'order' | 'emergency'
  selected_origin: string | null
  eta_cycles: number
  total_cost: number
  urgency_score: number
  priority_class: 'RED' | 'YELLOW' | 'GREEN'
  reason_codes: string[]
  top_k_options: SupplyOption[]
}

interface SupplyDecisionResponse {
  aircraft_id: string | null
  location_id: string
  deadline_cycles: number
  urgency_score: number
  priority_class: 'RED' | 'YELLOW' | 'GREEN'
  decisions: SupplyPartDecision[]
}

interface PendingPartRequest {
  partNumber: string
  option: SupplyOption
}

interface FormPart {
  part_number: string
  quantity: number
  supplier_lead_time_cycles: string | number
  supplier_cost: string | number
}

interface LocationOption {
  location_code: string
  location_name: string
  place: string | null
}

interface SparePartOption {
  part_number: string
  name: string
}

interface AircraftOption {
  aircraft_id: string
  operator: string | null
  model: string | null
  base_location: string | null
  engine_ids: string | null
}

interface PredictionResponse {
  engine_id: number
  predicted_rul: number
}

interface MaintenanceUrgencyResponse {
  risk_probability: number
}

interface Engine {
  engineid: string
  manifacturer: string | null
  engine_serial_number: string | null
  position_on_iarcraft: string | null
  installation_date: string | null
}

interface EngineHealth {
  predicted_rul: number | null
  risk_30: number | null
}

const aircraftId = ref('AC-001')
const locationId = ref('LHR')
const rulCycles = ref(14)
const risk30 = ref(0.52)
const topK = ref(3)
const locations = ref<LocationOption[]>([])
const aircrafts = ref<AircraftOption[]>([])
const spareParts = ref<SparePartOption[]>([])
const syncingAircraft = ref(false)
const loadingEngineHealth = ref(false)
const enginesForSelectedAircraft = ref<Engine[]>([])
const engineHealthByEngineId = ref<Record<string, EngineHealth>>({})
const engineUrgencyByTag = ref<Record<string, number>>({})
const selectedEngineId = ref<string | null>(null)

const parts = ref<FormPart[]>([
  {
    part_number: 'SP-ENG-0004',
    quantity: 1,
    supplier_lead_time_cycles: 18,
    supplier_cost: 1200,
  },
])

const loading = ref(false)
const error = ref('')
const result = ref<SupplyDecisionResponse | null>(null)
const pendingPartRequest = ref<PendingPartRequest | null>(null)
const partRequestSucceeded = ref(false)
const route = useRoute()
const router = useRouter()

function normalizeRouteAircraftId(value: unknown): string {
  return typeof value === 'string' ? value.trim() : ''
}

function normalizeRouteEngineId(value: unknown): string {
  return typeof value === 'string' ? value.trim() : ''
}

function replaceSupplyRoute(selectedAircraftId: string, engineId?: string | null) {
  if (engineId) {
    return router.replace({
      name: 'supply-engine-decision',
      params: { aircraftid: selectedAircraftId, engineid: engineId },
    })
  }

  return router.replace({
    name: 'supply-decision',
    params: { aircraftid: selectedAircraftId },
  })
}

function locationLabel(locationCode: string | null): string {
  if (!locationCode) return 'Unknown airport'
  const location = locations.value.find((item) => item.location_code === locationCode)
  if (!location) return locationCode
  return [location.location_code, location.location_name, location.place]
    .filter((value) => Boolean(value))
    .join(' - ')
}

function originLabel(originCode: string | null): string {
  if (!originCode) return 'SUPPLIER'
  return locationLabel(originCode)
}

function aircraftLabel(aircraft: AircraftOption): string {
  return [
    aircraft.aircraft_id,
    aircraft.operator ?? 'Unknown operator',
    aircraft.model ?? 'Unknown model',
    locationLabel(aircraft.base_location),
  ].join(' - ')
}

function sparePartLabel(part: SparePartOption): string {
  return `${part.part_number} - ${part.name}`
}

function sparePartLabelByNumber(partNumber: string): string {
  const part = spareParts.value.find((option) => option.part_number === partNumber)
  return part ? sparePartLabel(part) : partNumber
}

function partRequestSummary(request: PendingPartRequest): string {
  const partLabel = sparePartLabelByNumber(request.partNumber)
  const destination = locationLabel(result.value?.location_id ?? locationId.value)
  const eta = request.option.eta_cycles.toFixed(2)

  if (request.option.decision === 'transfer') {
    return `Do you want to request the transfer of component ${partLabel} from the warehouse at ${originLabel(request.option.selected_origin)} to the destination airport ${destination} (ETA ${eta} cycles)?`
  }

  return `Do you want to start a purchase order for component ${partLabel}, to be delivered to ${destination} (ETA ${eta} cycles)?`
}

function openPartRequest(partNumber: string, option: SupplyOption) {
  pendingPartRequest.value = { partNumber, option }
  partRequestSucceeded.value = false
}

function confirmPartRequest() {
  partRequestSucceeded.value = true
}

function closePartRequest() {
  pendingPartRequest.value = null
  partRequestSucceeded.value = false
}

function toInputText(value: string | number | null | undefined): string {
  return value === null || value === undefined ? '' : String(value)
}

function selectedEngineHealth() {
  if (!selectedEngineId.value) return null
  return engineHealthByEngineId.value[selectedEngineId.value] ?? null
}

function syncDecisionInputsFromSelectedEngine() {
  const health = selectedEngineHealth()
  if (!health) return
  if (health.predicted_rul !== null) {
    rulCycles.value = health.predicted_rul
  }
  if (health.risk_30 !== null) {
    risk30.value = health.risk_30
  }
}

function handleEngineSelection(engineId: string) {
  selectedEngineId.value = engineId
  syncDecisionInputsFromSelectedEngine()
  void replaceSupplyRoute(aircraftId.value, engineId)
}

async function loadLocations() {
  try {
    const res = await fetch(`${API_BASE_URL}/v1/locations`)
    if (!res.ok) return
    const data = (await res.json()) as LocationOption[]
    locations.value = data

    if (data.length > 0 && !data.some((l) => l.location_code === locationId.value)) {
      locationId.value = data[0].location_code
    }
  } catch {
    /* best effort: keep form usable even if locations endpoint is unavailable */
  }
}

async function loadAircrafts() {
  try {
    const res = await fetch(`${API_BASE_URL}/v1/aircraft`)
    if (!res.ok) return
    const data = (await res.json()) as AircraftOption[]
    aircrafts.value = data

    const routeAircraftId = normalizeRouteAircraftId(route.params.aircraftid)
    if (routeAircraftId && data.some((a) => a.aircraft_id === routeAircraftId)) {
      aircraftId.value = routeAircraftId
      return
    }

    if (data.length > 0 && !data.some((a) => a.aircraft_id === aircraftId.value)) {
      aircraftId.value = data[0].aircraft_id
    }
  } catch {
    /* best effort: keep form usable even if aircraft endpoint is unavailable */
  }
}

async function loadSpareParts() {
  try {
    const res = await fetch(`${API_BASE_URL}/v1/supply/parts`)
    if (!res.ok) return
    spareParts.value = (await res.json()) as SparePartOption[]

    if (spareParts.value.length > 0) {
      for (const part of parts.value) {
        if (!spareParts.value.some((option) => option.part_number === part.part_number)) {
          part.part_number = spareParts.value[0].part_number
        }
      }
    }
  } catch {
    /* best effort: keep form usable even if spare parts endpoint is unavailable */
  }
}

function primaryEngineId(engineIds: string | null, aircraftCode: string): string {
  const ids = parseEngineIds(engineIds, aircraftCode)
  return ids[0]
}

async function syncFromAircraftSelection(selectedAircraftId: string) {
  const selected = aircrafts.value.find((a) => a.aircraft_id === selectedAircraftId)
  if (!selected) return

  syncingAircraft.value = true

  if (selected.base_location) {
    locationId.value = selected.base_location
  }

  try {
    const engineId = primaryEngineId(selected.engine_ids, selected.aircraft_id)
    const predictionRes = await fetch(`${API_BASE_URL}/v1/predictions/${encodeURIComponent(engineId)}`)
    if (!predictionRes.ok) return

    const prediction = (await predictionRes.json()) as PredictionResponse
    rulCycles.value = Number(prediction.predicted_rul.toFixed(2))

    const urgencyRes = await fetch(`${API_BASE_URL}/v1/maintenance/urgency`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ rul: prediction.predicted_rul, horizon_cycles: 30 }),
    })

    if (!urgencyRes.ok) return
    const urgency = (await urgencyRes.json()) as MaintenanceUrgencyResponse
    risk30.value = Number(Math.min(1, Math.max(0, urgency.risk_probability)).toFixed(4))
  } catch {
    /* best effort: leave current values if backend call fails */
  } finally {
    syncingAircraft.value = false
  }
}

function parseEngineIds(engineIds: string | null, aircraftCode: string): string[] {
  const parsed = (engineIds ?? '')
    .split(/[;,]/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0)

  if (parsed.length > 0) return parsed
  return [aircraftCode]
}

async function loadEngineHealthForAircraft(selectedAircraftId: string) {
  const selected = aircrafts.value.find((a) => a.aircraft_id === selectedAircraftId)
  if (!selected) {
    enginesForSelectedAircraft.value = []
    engineHealthByEngineId.value = {}
    engineUrgencyByTag.value = {}
    return
  }

  loadingEngineHealth.value = true
  enginesForSelectedAircraft.value = []
  engineHealthByEngineId.value = {}
  engineUrgencyByTag.value = {}
  selectedEngineId.value = null

  const engineIds = parseEngineIds(selected.engine_ids, selected.aircraft_id)

  try {
    const rows = await Promise.all(
      engineIds.map(async (engineId) => {
        try {
          const engineRes = await fetch(`${API_BASE_URL}/v1/engine/${encodeURIComponent(engineId)}`)
          const engineDetails = engineRes.ok ? ((await engineRes.json()) as Engine) : null

          const predictionRes = await fetch(`${API_BASE_URL}/v1/predictions/${encodeURIComponent(engineId)}`)
          if (!predictionRes.ok) {
            return {
              engineDetails,
              engineId,
              health: { predicted_rul: null, risk_30: null },
              urgencyLevel: 1,
            }
          }

          const prediction = (await predictionRes.json()) as PredictionResponse
          const urgencyRes = await fetch(`${API_BASE_URL}/v1/maintenance/urgency`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ rul: prediction.predicted_rul, horizon_cycles: 30 }),
          })

          if (!urgencyRes.ok) {
            return {
              engineDetails,
              engineId,
              health: {
                predicted_rul: Number(prediction.predicted_rul.toFixed(2)),
                risk_30: null,
              },
              urgencyLevel: 1,
            }
          }

          const urgency = (await urgencyRes.json()) as MaintenanceUrgencyResponse
          const risk = Number(Math.min(1, Math.max(0, urgency.risk_probability)).toFixed(4))
          const urgencyLevel = risk >= 0.6 ? 3 : risk >= 0.3 ? 2 : 1

          return {
            engineDetails,
            engineId,
            health: {
              predicted_rul: Number(prediction.predicted_rul.toFixed(2)),
              risk_30: risk,
            },
            urgencyLevel,
          }
        } catch {
          return {
            engineDetails: null,
            engineId,
            health: { predicted_rul: null, risk_30: null },
            urgencyLevel: 1,
          }
        }
      }),
    )

    enginesForSelectedAircraft.value = rows.map((row) => {
      if (row.engineDetails) return row.engineDetails
      return {
        engineid: row.engineId,
        manifacturer: null,
        engine_serial_number: null,
        position_on_iarcraft: null,
        installation_date: null,
      }
    })

    engineHealthByEngineId.value = Object.fromEntries(
      rows.map((row) => [row.engineId, row.health]),
    )

    engineUrgencyByTag.value = Object.fromEntries(
      rows.map((row) => [row.engineId, row.urgencyLevel]),
    )

    if (rows.length > 0) {
      const routeEngineId = normalizeRouteEngineId(route.params.engineid)
      const routeMatchesAircraft = normalizeRouteAircraftId(route.params.aircraftid) === selectedAircraftId
      const selectedId = routeMatchesAircraft && rows.some((row) => row.engineId === routeEngineId)
        ? routeEngineId
        : rows[0].engineId
      selectedEngineId.value = selectedId
      syncDecisionInputsFromSelectedEngine()
      void replaceSupplyRoute(selectedAircraftId, selectedId)
    }
  } finally {
    loadingEngineHealth.value = false
  }
}

function addPart() {
  parts.value.push({
    part_number: spareParts.value[0]?.part_number ?? '',
    quantity: 1,
    supplier_lead_time_cycles: 18,
    supplier_cost: 1200,
  })
}

function removePart(index: number) {
  parts.value.splice(index, 1)
}

function buildPayload() {
  const payloadParts: SupplyPartRequest[] = parts.value
    .filter((p) => p.part_number.trim().length > 0)
    .map((p) => {
      const supplierLeadTime = toInputText(p.supplier_lead_time_cycles).trim()
      const supplierCost = toInputText(p.supplier_cost).trim()

      if (supplierLeadTime.length === 0) {
        throw new Error(`Supplier Lead Time is required for ${p.part_number || 'a part'}`)
      }
      if (supplierCost.length === 0) {
        throw new Error(`Supplier Cost is required for ${p.part_number || 'a part'}`)
      }
      const item: SupplyPartRequest = {
        part_number: p.part_number.trim(),
        quantity: Number(p.quantity),
        supplier_lead_time_cycles: Number(supplierLeadTime),
        supplier_cost: Number(supplierCost),
      }
      return item
    })

  return {
    aircraft_id: aircraftId.value.trim() || null,
    location_id: locationId.value.trim(),
    rul_cycles: Number(rulCycles.value),
    risk_30: Number(risk30.value),
    parts: payloadParts,
    top_k: Number(topK.value),
  }
}

async function runDecision() {
  error.value = ''
  result.value = null

  let payload: ReturnType<typeof buildPayload>
  try {
    payload = buildPayload()
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err)
    return
  }

  if (!payload.location_id) {
    error.value = 'Location is required.'
    return
  }
  if (payload.parts.length === 0) {
    error.value = 'At least one part is required.'
    return
  }

  loading.value = true
  try {
    const res = await fetch(`${API_BASE_URL}/v1/supply/decision`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    })

    if (!res.ok) {
      let detail = `HTTP ${res.status}`
      try {
        const body = await res.json()
        if (body?.detail) detail = body.detail
      } catch {
        /* ignore non-json response */
      }
      throw new Error(detail)
    }

    result.value = await res.json()
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
}

function priorityClass(priority: 'RED' | 'YELLOW' | 'GREEN') {
  if (priority === 'RED') return 'pill pill--red'
  if (priority === 'YELLOW') return 'pill pill--yellow'
  return 'pill pill--green'
}

watch(aircraftId, (selectedId, previousId) => {
  if (!selectedId || selectedId === previousId) return
  if (normalizeRouteAircraftId(route.params.aircraftid) !== selectedId) {
    void replaceSupplyRoute(selectedId)
  }
  void syncFromAircraftSelection(selectedId)
  void loadEngineHealthForAircraft(selectedId)
})

watch(
  () => route.params.aircraftid,
  (nextAircraftId) => {
    const normalized = normalizeRouteAircraftId(nextAircraftId)
    if (normalized && normalized !== aircraftId.value) {
      aircraftId.value = normalized
    }
  },
)

watch(
  () => route.params.engineid,
  (nextEngineId) => {
    const normalized = normalizeRouteEngineId(nextEngineId)
    if (
      normalized &&
      normalized !== selectedEngineId.value &&
      enginesForSelectedAircraft.value.some((engine) => engine.engineid === normalized)
    ) {
      selectedEngineId.value = normalized
      syncDecisionInputsFromSelectedEngine()
    }
  },
)

onMounted(async () => {
  await Promise.all([loadLocations(), loadAircrafts(), loadSpareParts()])
  if (aircraftId.value) {
    await Promise.all([
      syncFromAircraftSelection(aircraftId.value),
      loadEngineHealthForAircraft(aircraftId.value),
    ])
  }
})
</script>

<template>
  <div class="supply-page">
    <PageHeader title="Supply Decision" root-label="Spare Optimization" :root-to="{ name: 'home' }" />

    <section class="panel form-panel">
      <h2>Request</h2>
      <div class="form-grid">
        <label>
          Aircraft ID
          <select v-model="aircraftId">
            <option
              v-for="aircraft in aircrafts"
              :key="aircraft.aircraft_id"
              :value="aircraft.aircraft_id"
            >
              {{ aircraftLabel(aircraft) }}
            </option>
          </select>
        </label>
        <label>
          Top K
          <input v-model.number="topK" type="number" min="1" max="20" step="1" />
        </label>
      </div>

      <section class="panel">
        <h2>Engines</h2>
        <p v-if="loadingEngineHealth" class="hint">Loading engine RUL and risk...</p>
        <EngineListTable
          v-else
          :engines="enginesForSelectedAircraft"
          :aircraft-id="aircraftId"
          :urgency-by-engine-id="engineUrgencyByTag"
          :health-by-engine-id="engineHealthByEngineId"
          :show-health-columns="true"
          :selectable="true"
          :selected-engine-id="selectedEngineId"
          empty-label="No engine data available for the selected aircraft."
          @select-engine="handleEngineSelection"
        />
      </section>

      <h3>Parts</h3>
      <div class="parts-stack">
        <div v-for="(part, idx) in parts" :key="idx" class="part-row">
          <label>
            Part Number
            <select v-model="part.part_number" required>
              <option v-for="option in spareParts" :key="option.part_number" :value="option.part_number">
                {{ sparePartLabel(option) }}
              </option>
            </select>
          </label>
          <div class="part-row__side">
            <label>
              Quantity
              <input v-model.number="part.quantity" type="number" min="1" step="1" required />
            </label>
            <label>
              Supplier Lead Time
              <input v-model="part.supplier_lead_time_cycles" type="number" min="1" step="1" placeholder="18" required />
            </label>
            <label>
              Supplier Cost
              <input v-model="part.supplier_cost" type="number" min="0" step="0.01" placeholder="1200" required />
            </label>
            <button
              v-if="parts.length > 1"
              type="button"
              class="btn btn--ghost part-row__remove"
              @click="removePart(idx)"
            >
              Remove
            </button>
          </div>
        </div>
      </div>

      <div class="actions">
        <button type="button" class="btn btn--ghost" @click="addPart">Add part</button>
        <button type="button" class="btn" :disabled="loading" @click="runDecision">
          {{ loading ? 'Calculating...' : 'Run decision' }}
        </button>
      </div>

      <p v-if="syncingAircraft" class="hint">Auto-syncing location, RUL and risk from selected aircraft...</p>
      <p class="hint">
        Destination location: <strong>{{ locationLabel(locationId) }}</strong>
      </p>
      <p class="hint">
        Selected engine: <strong>{{ selectedEngineId ?? 'None' }}</strong>
        <template v-if="selectedEngineHealth()">
          | RUL: <strong>{{ selectedEngineHealth()?.predicted_rul !== null ? selectedEngineHealth()?.predicted_rul?.toFixed(2) : 'N/A' }}</strong>
          | Risk 30: <strong>{{ selectedEngineHealth()?.risk_30 !== null ? `${((selectedEngineHealth()?.risk_30 ?? 0) * 100).toFixed(2)}%` : 'N/A' }}</strong>
        </template>
      </p>

      <p v-if="error" class="error">{{ error }}</p>
    </section>

    <section v-if="result" class="panel result-panel">
      <h2>Decision Result</h2>
      <div class="summary-row">
        <span>Location: <strong>{{ locationLabel(result.location_id) }}</strong></span>
        <span>Deadline: <strong>{{ result.deadline_cycles.toFixed(2) }}</strong> cycles</span>
        <span>Urgency Score: <strong>{{ result.urgency_score.toFixed(3) }}</strong></span>
        <span :class="priorityClass(result.priority_class)">{{ result.priority_class }}</span>
      </div>

      <div class="decision-stack">
        <article v-for="item in result.decisions" :key="item.part_number" class="decision-card">
          <header class="decision-header">
            <h3>{{ sparePartLabelByNumber(item.part_number) }} x{{ item.quantity }}</h3>
            <span :class="priorityClass(item.priority_class)">{{ item.decision.toUpperCase() }}</span>
          </header>

          <p class="decision-meta">
            Origin: {{ originLabel(item.selected_origin) }} |
            ETA: {{ item.eta_cycles.toFixed(2) }} cycles |
            Cost: {{ item.total_cost.toFixed(2) }}
          </p>
          <p class="reason-codes">Reasons: {{ item.reason_codes.join(', ') }}</p>

          <h4>Top options</h4>
          <div class="options-table-wrap">
            <table class="options-table">
              <thead>
                <tr>
                  <th>Decision</th>
                  <th>Origin</th>
                  <th>ETA</th>
                  <th>Cost</th>
                  <th>Score</th>
                  <th>Feasible</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(opt, i) in item.top_k_options" :key="`${item.part_number}-${i}`">
                  <td>{{ opt.decision }}</td>
                  <td>{{ originLabel(opt.selected_origin) }}</td>
                  <td>{{ opt.eta_cycles.toFixed(2) }}</td>
                  <td>{{ opt.total_cost.toFixed(2) }}</td>
                  <td>{{ opt.score.toFixed(2) }}</td>
                  <td>
                    <div class="feasible-cell">
                      <span>{{ opt.feasible ? 'yes' : 'no' }}</span>
                      <button
                        v-if="opt.eta_cycles > 0"
                        type="button"
                        class="btn request-part-btn"
                        @click="openPartRequest(item.part_number, opt)"
                      >
                        Request part
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </article>
      </div>
    </section>

    <div v-if="pendingPartRequest" class="modal-backdrop" @click.self="closePartRequest">
      <section class="request-modal" role="dialog" aria-modal="true" aria-labelledby="request-part-title">
        <template v-if="!partRequestSucceeded">
          <h2 id="request-part-title">Request part</h2>
          <p>{{ partRequestSummary(pendingPartRequest) }}</p>
          <div class="modal-actions">
            <button type="button" class="btn btn--ghost" @click="closePartRequest">Cancel</button>
            <button type="button" class="btn" @click="confirmPartRequest">OK</button>
          </div>
        </template>
        <template v-else>
          <h2 id="request-part-title">Request submitted</h2>
          <p>Request submitted successfully.</p>
          <div class="modal-actions">
            <button type="button" class="btn" @click="closePartRequest">OK</button>
          </div>
        </template>
      </section>
    </div>
  </div>
</template>

<style scoped>
.supply-page {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding: 24px;
}

.panel {
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 20px;
  background: var(--bg);
  text-align: left;
}

.panel h2 {
  margin-top: 0;
}

.panel .panel {
  margin-top: 18px;
}

h2 {
  margin: 0 0 16px;
}

h3 {
  margin: 16px 0 12px;
}

h4 {
  margin: 14px 0 10px;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 12px;
}

.parts-stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.part-row {
  display: grid;
  grid-template-columns: 40% 60%;
  gap: 12px;
  padding: 12px;
  border: 1px solid var(--border);
  border-radius: 10px;
}

.part-row__side {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  align-items: end;
}

.part-row__remove {
  grid-column: 1 / -1;
  justify-self: end;
}

label {
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 0.9rem;
}

input {
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 8px 10px;
  background: var(--bg);
  color: var(--text-h);
}

select {
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 8px 10px;
  background: var(--bg);
  color: var(--text-h);
}

.actions {
  margin-top: 16px;
  display: flex;
  gap: 10px;
}

.btn {
  border: 1px solid var(--accent-border);
  background: var(--accent);
  color: white;
  border-radius: 8px;
  padding: 10px 14px;
  font-weight: 600;
  cursor: pointer;
}

.btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.btn--ghost {
  border: 1px solid var(--border);
  background: transparent;
  color: var(--text-h);
}

.error {
  margin-top: 12px;
  color: #b91c1c;
  font-weight: 600;
}

.hint {
  margin-top: 12px;
  color: var(--text);
  font-size: 0.9rem;
}

.summary-row {
  display: flex;
  flex-wrap: wrap;
  gap: 14px;
  align-items: center;
  margin-bottom: 14px;
}

.pill {
  border-radius: 999px;
  padding: 4px 10px;
  font-size: 0.8rem;
  font-weight: 700;
}

.pill--red {
  background: rgba(220, 38, 38, 0.18);
  color: #991b1b;
}

.pill--yellow {
  background: rgba(202, 138, 4, 0.2);
  color: #854d0e;
}

.pill--green {
  background: rgba(22, 163, 74, 0.18);
  color: #166534;
}

.decision-stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.decision-card {
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 14px;
}

.decision-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
}

.decision-header h3 {
  margin: 0;
}

.decision-meta,
.reason-codes {
  margin-top: 8px;
  color: var(--text);
}

.options-table-wrap {
  overflow-x: auto;
}

.options-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9rem;
}

.options-table th,
.options-table td {
  text-align: left;
  border-bottom: 1px solid var(--border);
  padding: 8px 6px;
}

.feasible-cell {
  display: flex;
  align-items: center;
  gap: 8px;
  white-space: nowrap;
}

.request-part-btn {
  padding: 6px 9px;
  font-size: 0.78rem;
}

.modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 1000;
  display: grid;
  place-items: center;
  padding: 20px;
  background: rgba(15, 23, 42, 0.58);
}

.request-modal {
  width: min(520px, 100%);
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--bg);
  color: var(--text-h);
  padding: 20px;
  box-shadow: 0 18px 50px rgba(0, 0, 0, 0.28);
}

.request-modal h2 {
  margin-bottom: 12px;
}

.request-modal p {
  margin: 0;
  line-height: 1.55;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 20px;
}

@media (max-width: 768px) {
  .supply-page {
    padding: 14px;
  }

  .part-row {
    grid-template-columns: 1fr;
  }

  .part-row__side {
    grid-template-columns: 1fr;
  }

  .part-row__remove {
    justify-self: stretch;
  }
}
</style>
