<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import PageHeader from '../components/PageHeader.vue'
import StatusBadge from '../components/StatusBadge.vue'
import { API_BASE_URL } from '../config'

interface Aircraft {
  aircraft_id: string
  model: string | null
  engine_count: number | null
  engine_ids: string | null
  operator: string | null
  total_flight_cycles: number | null
  status: string | null
  msn: string | null
  in_service_date: string | null
  total_flight_hours: number | null
  base_location: string | null
}

interface Location {
  location_code: string
  location_name: string
  place: string
}

interface Engine {
  engineid: string
  manifacturer: string | null
  engine_serial_number: string | null
  position_on_iarcraft: string | null
  installation_date: string | null
}

interface Prediction {
  engine_id: number
  predicted_rul: number
}

interface EvaluationMetric {
  name: string
  value: number
}

type BadgeStatus = 'red' | 'yellow' | 'green'

const route = useRoute()

const loading = ref(false)
const error = ref('')
const aircraft = ref<Aircraft | null>(null)
const location = ref<Location | null>(null)
const engines = ref<Engine[]>([])
const engineUrgencyByTag = ref<Record<string, number>>({})

const DEFAULT_HORIZON_CYCLES = 30
const YELLOW_FROM = 0.3
const RED_FROM = 0.6

const aircraftId = computed(() => String(route.params.aircraftid ?? ''))

const baseLocationDisplay = computed(() => {
  if (location.value) {
    return `${location.value.location_code} - ${location.value.location_name} - ${location.value.place}`
  }
  return aircraft.value?.base_location ?? '—'
})

function normalCdf(x: number): number {
  const sign = x < 0 ? -1 : 1
  const abs = Math.abs(x) / Math.sqrt(2)
  const t = 1 / (1 + 0.3275911 * abs)
  const a1 = 0.254829592
  const a2 = -0.284496736
  const a3 = 1.421413741
  const a4 = -1.453152027
  const a5 = 1.061405429
  const erfApprox = 1 - (((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t) * Math.exp(-abs * abs)
  return 0.5 * (1 + sign * erfApprox)
}

function classifyUrgencyLevel(predictedRul: number, mae: number, rmse: number): number {
  const z = (DEFAULT_HORIZON_CYCLES + mae - predictedRul) / rmse
  const pRisk = normalCdf(z)
  if (pRisk >= RED_FROM) return 3
  if (pRisk >= YELLOW_FROM) return 2
  return 1
}

function statusForUrgencyLevel(level?: number): BadgeStatus {
  if (level === 3) return 'red'
  if (level === 2) return 'yellow'
  return 'green'
}

function engineBadgeStatus(engineTag: string): BadgeStatus {
  return statusForUrgencyLevel(engineUrgencyByTag.value[engineTag])
}

async function loadAircraft() {
  if (!aircraftId.value) {
    error.value = 'Missing aircraft id.'
    return
  }

  loading.value = true
  error.value = ''
  aircraft.value = null
  location.value = null
  engines.value = []
  engineUrgencyByTag.value = {}

  try {
    const res = await fetch(`${API_BASE_URL}/v1/aircraft/${encodeURIComponent(aircraftId.value)}`)
    if (!res.ok) {
      let detail = `HTTP ${res.status}`
      try {
        const body = await res.json()
        if (body?.detail) detail = body.detail
      } catch {
        /* response had no JSON body */
      }
      throw new Error(detail)
    }
    aircraft.value = await res.json()

    const locationCode = aircraft.value?.base_location?.trim()
    if (locationCode) {
      try {
        const locRes = await fetch(`${API_BASE_URL}/v1/location/${encodeURIComponent(locationCode)}`)
        if (locRes.ok) {
          location.value = await locRes.json()
        }
      } catch {
        // Best effort: if location API fails, keep showing raw location code.
      }
    }

    const ids = (aircraft.value?.engine_ids?.split(';') ?? [])
      .map((id) => id.trim())
      .filter(Boolean)

    if (ids.length > 0) {
      let mae: number | null = null
      let rmse: number | null = null

      try {
        const evalRes = await fetch(`${API_BASE_URL}/v1/evaluations`)
        if (evalRes.ok) {
          const metrics = (await evalRes.json()) as EvaluationMetric[]
          const maeRow = metrics.find((m) => m.name.toLowerCase() === 'mae')
          const rmseRow = metrics.find((m) => m.name.toLowerCase() === 'rmse')
          mae = maeRow?.value ?? null
          rmse = rmseRow?.value ?? null
        }
      } catch {
        /* best effort: badges fall back to green if metrics are unavailable */
      }

      if (mae !== null && rmse !== null && rmse > 0) {
        const urgencyEntries = await Promise.all(
          ids.map(async (id) => {
            try {
              const r = await fetch(`${API_BASE_URL}/v1/predictions/${encodeURIComponent(id)}`)
              if (!r.ok) return null
              const prediction = (await r.json()) as Prediction
              const level = classifyUrgencyLevel(prediction.predicted_rul, mae as number, rmse as number)
              return [id, level] as const
            } catch {
              return null
            }
          }),
        )

        engineUrgencyByTag.value = Object.fromEntries(
          urgencyEntries.filter((entry): entry is readonly [string, number] => entry !== null),
        )
      }

      const responses = await Promise.all(
        ids.map(async (id) => {
          try {
            const r = await fetch(`${API_BASE_URL}/v1/engine/${encodeURIComponent(id)}`)
            if (!r.ok) return null
            return (await r.json()) as Engine
          } catch {
            return null
          }
        }),
      )
      engines.value = responses.filter((x): x is Engine => x !== null)
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
}

watch(() => route.params.aircraftid, loadAircraft)
onMounted(loadAircraft)
</script>

<template>
  <div class="aircraft-detail-page">
    <PageHeader :title="`Aircraft ${aircraftId}`" />

    <section class="content">
      <p v-if="loading" class="state">Loading aircraft details…</p>
      <p v-else-if="error" class="state state--error">⚠️ {{ error }}</p>
      <p v-else-if="!aircraft" class="state">Aircraft not found.</p>

      <template v-else>
        <div class="panel">
          <div class="panel-head">
            <h2>{{ aircraft.aircraft_id }}</h2>
            <span class="chip">{{ aircraft.status ?? 'unknown' }}</span>
          </div>

          <dl class="details-grid">
            <div class="field">
              <dt>Model</dt>
              <dd>{{ aircraft.model ?? '—' }}</dd>
            </div>
            <div class="field">
              <dt>Operator</dt>
              <dd>{{ aircraft.operator ?? '—' }}</dd>
            </div>
            <div class="field">
              <dt>MSN</dt>
              <dd>{{ aircraft.msn ?? '—' }}</dd>
            </div>
            <div class="field">
              <dt>In Service Date</dt>
              <dd>{{ aircraft.in_service_date ?? '—' }}</dd>
            </div>
            <div class="field">
              <dt>Total Flight Cycles</dt>
              <dd>{{ aircraft.total_flight_cycles ?? '—' }}</dd>
            </div>
            <div class="field">
              <dt>Total Flight Hours</dt>
              <dd>{{ aircraft.total_flight_hours ?? '—' }}</dd>
            </div>
            <div class="field">
              <dt>Engine Count</dt>
              <dd>{{ aircraft.engine_count ?? '—' }}</dd>
            </div>
            <div class="field">
              <dt>Base Location</dt>
              <dd>{{ baseLocationDisplay }}</dd>
            </div>
            <div class="field field--full">
              <dt>Engine Details</dt>
              <dd>
                <table v-if="engines.length > 0" class="engine-table">
                  <thead>
                    <tr>
                      <th>Engine ID</th>
                      <th>Manufacturer</th>
                      <th>Serial Number</th>
                      <th>Position</th>
                      <th>Installation Date</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="eng in engines" :key="eng.engineid">
                      <td>
                        <div class="engine-id-cell">
                          <StatusBadge
                            :label="''"
                            :status="engineBadgeStatus(eng.engineid)"
                          />
                          <router-link
                            class="engine-link"
                            :to="{ name: 'engine-detail', params: { aircraftid: aircraftId, engineid: eng.engineid } }"
                          >
                            {{ eng.engineid }}
                          </router-link>
                        </div>
                      </td>
                      <td>{{ eng.manifacturer ?? '—' }}</td>
                      <td>{{ eng.engine_serial_number ?? '—' }}</td>
                      <td>{{ eng.position_on_iarcraft ?? '—' }}</td>
                      <td>{{ eng.installation_date ?? '—' }}</td>
                    </tr>
                  </tbody>
                </table>
                <span v-else>—</span>
              </dd>
            </div>
          </dl>
        </div>
      </template>
    </section>
  </div>
</template>

<style scoped>
.aircraft-detail-page {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 24px;
  padding: 32px;
}

.content {
  width: 100%;
}

.state {
  font-size: 0.95rem;
  color: var(--text);
}

.state--error {
  color: #e5484d;
  font-weight: 600;
}

.panel {
  width: 100%;
  border: 1px solid var(--border);
  border-radius: 12px;
  background: var(--bg);
  padding: 20px;
}

.panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 18px;
}

.panel-head h2 {
  margin: 0;
  font-size: 1.4rem;
}

.chip {
  font-size: 0.8rem;
  text-transform: uppercase;
  letter-spacing: 0.6px;
  border: 1px solid var(--accent-border);
  color: var(--accent);
  background: var(--accent-bg);
  border-radius: 999px;
  padding: 4px 10px;
  font-weight: 600;
}

.details-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px 18px;
  margin: 0;
}

.field {
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 10px 12px;
}

.field dt {
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.6px;
  color: var(--text);
  margin-bottom: 4px;
}

.field dd {
  margin: 0;
  color: var(--text-h);
  font-weight: 600;
}

.engine-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.86rem;
}

.engine-table th,
.engine-table td {
  text-align: left;
  padding: 8px 10px;
  border-bottom: 1px solid var(--border);
}

.engine-table th {
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--text);
}

.engine-link {
  color: var(--accent);
  font-weight: 600;
  text-decoration: none;
}

.engine-link:hover {
  text-decoration: underline;
}

.engine-id-cell {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.field--full {
  grid-column: 1 / -1;
}

@media (max-width: 768px) {
  .aircraft-detail-page {
    padding: 24px 16px;
  }

  .details-grid {
    grid-template-columns: 1fr;
  }
}
</style>