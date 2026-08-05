<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import PageHeader from '../components/PageHeader.vue'
import { API_BASE_URL } from '../config'

interface Engine {
  engineid: string
  manifacturer: string | null
  engine_serial_number: string | null
  position_on_iarcraft: string | null
  installation_date: string | null
}

interface EngineDataRow {
  unit_number: number
  time_in_cycles: number
  operational_setting_1: number
  operational_setting_2: number
  operational_setting_3: number
  sensor_measurement_1: number
  sensor_measurement_2: number
  sensor_measurement_3: number
  sensor_measurement_4: number
  sensor_measurement_5: number
  sensor_measurement_6: number
  sensor_measurement_7: number
  sensor_measurement_8: number
  sensor_measurement_9: number
  sensor_measurement_10: number
  sensor_measurement_11: number
  sensor_measurement_12: number
  sensor_measurement_13: number
  sensor_measurement_14: number
  sensor_measurement_15: number
  sensor_measurement_16: number
  sensor_measurement_17: number
  sensor_measurement_18: number
  sensor_measurement_19: number
  sensor_measurement_20: number
  sensor_measurement_21: number
}

interface Prediction {
  engine_id: number
  predicted_rul: number
}

interface EvaluationMetric {
  name: string
  value: number
}

interface MaintenanceUrgency {
  level: number
  risk_probability: number
  explanation: string
  inputs: {
    rul: number
    horizon_cycles: number
    mae: number
    rmse: number
  }
  thresholds: {
    yellow_from: number
    red_from: number
  }
}

type MetricKey =
  | 'operational_setting_1'
  | 'operational_setting_2'
  | 'operational_setting_3'
  | 'sensor_measurement_1'
  | 'sensor_measurement_2'
  | 'sensor_measurement_3'
  | 'sensor_measurement_4'
  | 'sensor_measurement_5'
  | 'sensor_measurement_6'
  | 'sensor_measurement_7'
  | 'sensor_measurement_8'
  | 'sensor_measurement_9'
  | 'sensor_measurement_10'
  | 'sensor_measurement_11'
  | 'sensor_measurement_12'
  | 'sensor_measurement_13'
  | 'sensor_measurement_14'
  | 'sensor_measurement_15'
  | 'sensor_measurement_16'
  | 'sensor_measurement_17'
  | 'sensor_measurement_18'
  | 'sensor_measurement_19'
  | 'sensor_measurement_20'
  | 'sensor_measurement_21'

interface MetricDef {
  key: MetricKey
  label: string
}

interface MetricSeries {
  key: MetricKey
  label: string
  path: string
  min: number
  max: number
  plotMin: number
  plotMax: number
  category: 'op' | 'sensor'
}

const route = useRoute()

const loading = ref(false)
const error = ref('')
const engine = ref<Engine | null>(null)
const engineData = ref<EngineDataRow[]>([])
const prediction = ref<Prediction | null>(null)
const maintenanceUrgency = ref<MaintenanceUrgency | null>(null)
const evaluations = ref<EvaluationMetric[]>([])
const hoverIndex = ref<number | null>(null)
const hoverMetricKey = ref<MetricKey | null>(null)

const aircraftId = computed(() => String(route.params.aircraftid ?? ''))
const engineId = computed(() => String(route.params.engineid ?? ''))

const engineDataId = computed(() => {
  const m = engineId.value.match(/(\d+)/)
  return m ? Number(m[1]) : Number.NaN
})

const chartWidth = 360
const chartHeight = 72
const chartPad = 0

const metricDefs: MetricDef[] = [
  { key: 'operational_setting_1', label: 'Altitude Setpoint' },
  { key: 'operational_setting_2', label: 'Mach Setpoint' },
  { key: 'operational_setting_3', label: 'Throttle Resolver' },
  { key: 'sensor_measurement_1', label: 'Fan Inlet Temp' },
  { key: 'sensor_measurement_2', label: 'LPC Outlet Temp' },
  { key: 'sensor_measurement_3', label: 'HPC Outlet Temp' },
  { key: 'sensor_measurement_4', label: 'LPT Outlet Temp' },
  { key: 'sensor_measurement_5', label: 'Fan Speed N1' },
  { key: 'sensor_measurement_6', label: 'Core Speed N2' },
  { key: 'sensor_measurement_7', label: 'Fuel Flow' },
  { key: 'sensor_measurement_8', label: 'Oil Pressure' },
  { key: 'sensor_measurement_9', label: 'Oil Temperature' },
  { key: 'sensor_measurement_10', label: 'Vibration X' },
  { key: 'sensor_measurement_11', label: 'Vibration Y' },
  { key: 'sensor_measurement_12', label: 'Vibration Z' },
  { key: 'sensor_measurement_13', label: 'Bleed Pressure' },
  { key: 'sensor_measurement_14', label: 'Combustor Pressure' },
  { key: 'sensor_measurement_15', label: 'Turbine Exit Temp' },
  { key: 'sensor_measurement_16', label: 'Nozzle Pressure' },
  { key: 'sensor_measurement_17', label: 'Nozzle Area' },
  { key: 'sensor_measurement_18', label: 'Ambient Temp' },
  { key: 'sensor_measurement_19', label: 'Ambient Pressure' },
  { key: 'sensor_measurement_20', label: 'Corrected N1' },
  { key: 'sensor_measurement_21', label: 'Corrected N2' },
]

function buildMetricPath(values: number[], cycles: number[]) {
  if (values.length === 0 || cycles.length === 0) {
    return { path: '', min: 0, max: 0, plotMin: 0, plotMax: 1 }
  }

  const minVal = Math.min(...values)
  const maxVal = Math.max(...values)
  const minCycle = Math.min(...cycles)
  const maxCycle = Math.max(...cycles)

  const rawRange = maxVal - minVal
  const pad = rawRange > 0 ? rawRange * 0.2 : Math.max(Math.abs(maxVal) * 0.2, 1)
  const plotMin = minVal - pad
  const plotMax = maxVal + pad

  const valRange = plotMax - plotMin || 1
  const cycleRange = maxCycle - minCycle || 1

  const points = values.map((v, i) => {
    const x = chartPad + ((cycles[i] - minCycle) / cycleRange) * (chartWidth - chartPad * 2)
    const y = chartHeight - chartPad - ((v - plotMin) / valRange) * (chartHeight - chartPad * 2)
    return `${x.toFixed(2)},${y.toFixed(2)}`
  })

  return {
    path: `M ${points.join(' L ')}`,
    min: minVal,
    max: maxVal,
    plotMin,
    plotMax,
  }
}

const metricSeries = computed<MetricSeries[]>(() => {
  if (engineData.value.length === 0) return []

  const cycles = engineData.value.map((r) => r.time_in_cycles)
  return metricDefs.map(({ key, label }) => {
    const values = engineData.value.map((r) => Number(r[key]))
    const built = buildMetricPath(values, cycles)
    return {
      key,
      label,
      path: built.path,
      min: built.min,
      max: built.max,
      plotMin: built.plotMin,
      plotMax: built.plotMax,
      category: key.startsWith('operational_setting_') ? 'op' : 'sensor',
    }
  })
})

const opSeries = computed(() => metricSeries.value.filter((s) => s.category === 'op'))
const sensorSeries = computed(() => metricSeries.value.filter((s) => s.category === 'sensor'))

const cycleValues = computed(() => engineData.value.map((r) => r.time_in_cycles))

const minCycle = computed(() =>
  cycleValues.value.length > 0 ? Math.min(...cycleValues.value) : 0,
)

const maxCycle = computed(() =>
  cycleValues.value.length > 0 ? Math.max(...cycleValues.value) : 0,
)

const hoverCycle = computed<number | null>(() => {
  if (hoverIndex.value === null) return null
  return cycleValues.value[hoverIndex.value] ?? null
})

const hoverX = computed(() => {
  if (hoverCycle.value === null) return null
  const cycleRange = maxCycle.value - minCycle.value || 1
  return chartPad + ((hoverCycle.value - minCycle.value) / cycleRange) * (chartWidth - chartPad * 2)
})

const telemetryCycleCount = computed(() => engineData.value.length)

const telemetryCoverageText = computed(() => {
  if (telemetryCycleCount.value === 0) return 'No telemetry evidence available'
  return `Cycles ${minCycle.value} to ${maxCycle.value} (${telemetryCycleCount.value} points)`
})

const telemetryFreshnessText = computed(() => {
  if (telemetryCycleCount.value === 0) return 'Unknown'
  return `Latest observed cycle: ${maxCycle.value}`
})

const modelMae = computed(() => {
  const row = evaluations.value.find((e) => e.name.toLowerCase() === 'mae')
  return row?.value ?? null
})

const modelRmse = computed(() => {
  const row = evaluations.value.find((e) => e.name.toLowerCase() === 'rmse')
  return row?.value ?? null
})

const cautionZ = 1.65
const horizonCycles = 30

const conservativeRul = computed(() => {
  if (!prediction.value || modelRmse.value === null) return null
  return prediction.value.predicted_rul - cautionZ * modelRmse.value
})

const riskProbability = computed(() => maintenanceUrgency.value?.risk_probability ?? null)

const urgencyBand = computed<'High' | 'Medium' | 'Low' | 'Unknown'>(() => {
  if (!maintenanceUrgency.value) return 'Unknown'
  if (maintenanceUrgency.value.level === 3) return 'High'
  if (maintenanceUrgency.value.level === 2) return 'Medium'
  if (maintenanceUrgency.value.level === 1) return 'Low'
  return 'Unknown'
})

const urgencyClass = computed(() => {
  if (!maintenanceUrgency.value) return ''
  if (maintenanceUrgency.value.level === 3) return 'evidence-value--high'
  if (maintenanceUrgency.value.level === 2) return 'evidence-value--medium'
  if (maintenanceUrgency.value.level === 1) return 'evidence-value--low'
  return ''
})

const urgencyLevelText = computed(() => {
  if (!maintenanceUrgency.value) return '—'
  return `Level ${maintenanceUrgency.value.level}`
})

const shouldVerifySparePartAvailability = computed(() =>
  (maintenanceUrgency.value?.level ?? 0) >= 2,
)

const predictionMappingText = computed(() => {
  if (!prediction.value) return 'No prediction row'
  if (Number.isNaN(engineDataId.value)) return `Model unit ${prediction.value.engine_id}`
  const status = prediction.value.engine_id === engineDataId.value ? 'matched' : 'mismatch'
  return `Model unit ${prediction.value.engine_id} (${status} to page id ${engineDataId.value})`
})

function nearestIndexForClientX(clientX: number, svg: SVGSVGElement): number | null {
  if (engineData.value.length === 0) return null
  const rect = svg.getBoundingClientRect()
  if (rect.width <= 0) return null

  const xInSvg = ((clientX - rect.left) / rect.width) * chartWidth
  const minX = chartPad
  const maxX = chartWidth - chartPad
  const clamped = Math.max(minX, Math.min(maxX, xInSvg))
  const ratio = (clamped - minX) / (maxX - minX || 1)
  const idx = Math.round(ratio * (engineData.value.length - 1))
  return Math.max(0, Math.min(engineData.value.length - 1, idx))
}

function onChartMove(event: MouseEvent, key: MetricKey) {
  const target = event.currentTarget
  if (!(target instanceof SVGSVGElement)) return
  const idx = nearestIndexForClientX(event.clientX, target)
  if (idx === null) return
  hoverIndex.value = idx
  hoverMetricKey.value = key
}

function clearHover() {
  hoverIndex.value = null
  hoverMetricKey.value = null
}

function hoverValue(series: MetricSeries): number | null {
  if (hoverIndex.value === null) return null
  const row = engineData.value[hoverIndex.value]
  if (!row) return null
  return Number(row[series.key])
}

function hoverY(series: MetricSeries): number | null {
  const value = hoverValue(series)
  if (value === null) return null
  const valueRange = series.plotMax - series.plotMin || 1
  return chartHeight - chartPad - ((value - series.plotMin) / valueRange) * (chartHeight - chartPad * 2)
}

async function loadMaintenanceUrgency() {
  if (!prediction.value) {
    maintenanceUrgency.value = null
    return
  }

  try {
    const urgencyRes = await fetch(`${API_BASE_URL}/v1/maintenance/urgency`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        rul: prediction.value.predicted_rul,
        horizon_cycles: horizonCycles,
      }),
    })
    if (urgencyRes.ok) {
      maintenanceUrgency.value = await urgencyRes.json()
      return
    }
  } catch {
    /* best effort: keep view usable even if urgency API is unavailable */
  }

  maintenanceUrgency.value = null
}

async function loadEngine() {
  if (!engineId.value) {
    error.value = 'Missing engine id.'
    return
  }

  loading.value = true
  error.value = ''
  engine.value = null
  engineData.value = []
  prediction.value = null
  maintenanceUrgency.value = null
  evaluations.value = []

  try {
    const res = await fetch(`${API_BASE_URL}/v1/engine/${encodeURIComponent(engineId.value)}`)
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
    engine.value = await res.json()

    try {
      const predRes = await fetch(`${API_BASE_URL}/v1/predictions/${encodeURIComponent(engineId.value)}`)
      if (predRes.ok) {
        prediction.value = await predRes.json()
        await loadMaintenanceUrgency()
      }
    } catch {
      /* best effort: engine registry is still useful without a prediction */
    }

    try {
      const evalRes = await fetch(`${API_BASE_URL}/v1/evaluations`)
      if (evalRes.ok) {
        evaluations.value = await evalRes.json()
      }
    } catch {
      /* best effort: keep page usable even if model metrics are unavailable */
    }

    if (!Number.isNaN(engineDataId.value)) {
      try {
        const dataRes = await fetch(`${API_BASE_URL}/v1/engine/${engineDataId.value}/data`)
        if (dataRes.ok) {
          engineData.value = await dataRes.json()
        }
      } catch {
        /* best effort: engine registry is still useful without telemetry */
      }
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
}

watch(() => [route.params.aircraftid, route.params.engineid], loadEngine)
onMounted(loadEngine)
</script>

<template>
  <div class="engine-detail-page">
    <PageHeader
      :title="`Engine ${engineId}`"
      :root-label="`Aircraft ${aircraftId}`"
      :root-to="{ name: 'aircraft-detail', params: { aircraftid: aircraftId } }"
    />

    <section class="content">
      <p v-if="loading" class="state">Loading engine details…</p>
      <p v-else-if="error" class="state state--error">⚠️ {{ error }}</p>
      <p v-else-if="!engine" class="state">Engine not found.</p>

      <template v-else>
        <div class="panel">
          <h2>{{ engine.engineid }}</h2>
          <dl class="detail-grid">
            <div class="field">
              <dt>Manufacturer</dt>
              <dd>{{ engine.manifacturer ?? '—' }}</dd>
            </div>
            <div class="field">
              <dt>Serial Number</dt>
              <dd>{{ engine.engine_serial_number ?? '—' }}</dd>
            </div>
            <div class="field">
              <dt>Position On Aircraft</dt>
              <dd>{{ engine.position_on_iarcraft ?? '—' }}</dd>
            </div>
            <div class="field">
              <dt>Installation Date</dt>
              <dd>{{ engine.installation_date ?? '—' }}</dd>
            </div>
            <div class="field">
              <dt>Predicted RUL (cycles)</dt>
              <dd>{{ prediction ? prediction.predicted_rul.toFixed(2) : '—' }}</dd>
            </div>
          </dl>
        </div>

        <div class="panel rul-evidence-panel">
          <h3>RUL Evidence</h3>
          <dl class="evidence-grid">
            <div class="field evidence-field">
              <dt class="field-title-with-info">
                <span>Risk In Next {{ horizonCycles }} Cycles</span>
                <span
                  class="info-icon"
                  title="Estimated probability that this engine reaches the maintenance risk zone within the next 30 cycles, based on predicted RUL and model uncertainty."
                  aria-label="Info about risk in next cycles"
                >i</span>
              </dt>
              <dd :class="urgencyClass">
                {{ riskProbability !== null ? `${(riskProbability * 100).toFixed(1)}%` : '—' }}
                <span class="evidence-sub">{{ urgencyBand }} urgency · {{ urgencyLevelText }}</span>
                <RouterLink
                  v-if="shouldVerifySparePartAvailability"
                  class="spare-availability-link"
                  :to="{
                    name: 'supply-engine-decision',
                    params: { aircraftid: aircraftId, engineid: engineId },
                  }"
                >
                  Verify spare part availability
                </RouterLink>
              </dd>
            </div>
            <div class="field evidence-field">
              <dt class="field-title-with-info">
                <span>Conservative RUL (95%)</span>
                <span
                  class="info-icon"
                  title="A safety-adjusted Remaining Useful Life estimate that subtracts uncertainty from the raw prediction to reduce optimistic decisions."
                  aria-label="Info about conservative RUL"
                >i</span>
              </dt>
              <dd>
                {{ conservativeRul !== null ? conservativeRul.toFixed(2) : '—' }}
                <span class="evidence-sub">cycles (RUL - {{ cautionZ }} x RMSE)</span>
              </dd>
            </div>
            <div class="field evidence-field">
              <dt class="field-title-with-info">
                <span>Telemetry Coverage</span>
                <span
                  class="info-icon"
                  title="How much sensor history was available for this engine and the cycle window used as evidence for trend interpretation."
                  aria-label="Info about telemetry coverage"
                >i</span>
              </dt>
              <dd>
                {{ telemetryCoverageText }}
                <span class="evidence-sub">{{ telemetryFreshnessText }}</span>
              </dd>
            </div>
            <div class="field evidence-field">
              <dt class="field-title-with-info">
                <span>Model Error Context</span>
                <span
                  class="info-icon"
                  title="Global model validation quality. MAE is average absolute error, RMSE emphasizes larger errors and drives the risk and conservative RUL calculations."
                  aria-label="Info about model error context"
                >i</span>
              </dt>
              <dd>
                MAE {{ modelMae !== null ? modelMae.toFixed(2) : '—' }} | RMSE {{ modelRmse !== null ? modelRmse.toFixed(2) : '—' }}
                <span class="evidence-sub">Global validation metrics from evaluation table</span>
              </dd>
            </div>
            <div class="field evidence-field evidence-field--wide">
              <dt class="field-title-with-info">
                <span>Prediction Source Link</span>
                <span
                  class="info-icon"
                  title="Traceability check between the current engine page id and the model prediction row used to display RUL evidence."
                  aria-label="Info about prediction source link"
                >i</span>
              </dt>
              <dd>
                {{ predictionMappingText }}
                <span class="evidence-sub">Cross-check between route engine id and prediction row</span>
              </dd>
            </div>
          </dl>
        </div>

        <div class="panel">
          <h3>Engine Data Trends</h3>
          <p v-if="engineData.length === 0" class="state">No engine telemetry rows available for this id.</p>
          <div v-else class="metric-groups" @mouseleave="clearHover">
            <section class="metric-group metric-group--op">
              <h4 class="group-title">Operational Settings</h4>
              <div class="metric-list">
                <div
                  v-for="series in opSeries"
                  :key="series.key"
                  class="metric-row metric-row--op"
                >
                  <div class="metric-name">{{ series.label }}</div>
                  <div class="metric-chart-wrap">
                    <svg
                      class="metric-chart"
                      :viewBox="`0 0 ${chartWidth} ${chartHeight}`"
                      preserveAspectRatio="none"
                      role="img"
                      :aria-label="`Trend for ${series.label}`"
                      @mousemove="onChartMove($event, series.key)"
                    >
                      <line :x1="chartPad" :x2="chartWidth - chartPad" :y1="chartHeight - chartPad" :y2="chartHeight - chartPad" class="axis" />
                      <line :x1="chartPad" :x2="chartPad" :y1="chartPad" :y2="chartHeight - chartPad" class="axis" />
                      <line
                        v-if="hoverX !== null"
                        :x1="hoverX"
                        :x2="hoverX"
                        :y1="chartPad"
                        :y2="chartHeight - chartPad"
                        class="crosshair"
                      />
                      <path :d="series.path" class="trend-line trend-line--op" />
                      <circle
                        v-if="hoverX !== null && hoverY(series) !== null"
                        :cx="hoverX"
                        :cy="hoverY(series)!"
                        r="2.7"
                        class="hover-dot hover-dot--op"
                      />
                    </svg>
                    <div
                      v-if="hoverMetricKey === series.key && hoverX !== null && hoverValue(series) !== null && hoverCycle !== null"
                      class="chart-tooltip"
                      :style="{ left: `${(hoverX / chartWidth) * 100}%` }"
                    >
                      c{{ hoverCycle }} · {{ hoverValue(series)!.toFixed(2) }}
                    </div>
                  </div>
                  <div class="metric-range">
                    <span>max {{ series.max.toFixed(2) }}</span>
                    <span>min {{ series.min.toFixed(2) }}</span>
                  </div>
                </div>
              </div>
            </section>

            <section class="metric-group metric-group--sensor">
              <h4 class="group-title">Sensors</h4>
              <div class="metric-list">
                <div
                  v-for="series in sensorSeries"
                  :key="series.key"
                  class="metric-row metric-row--sensor"
                >
                  <div class="metric-name">{{ series.label }}</div>
                  <div class="metric-chart-wrap">
                    <svg
                      class="metric-chart"
                      :viewBox="`0 0 ${chartWidth} ${chartHeight}`"
                      preserveAspectRatio="none"
                      role="img"
                      :aria-label="`Trend for ${series.label}`"
                      @mousemove="onChartMove($event, series.key)"
                    >
                      <line :x1="chartPad" :x2="chartWidth - chartPad" :y1="chartHeight - chartPad" :y2="chartHeight - chartPad" class="axis" />
                      <line :x1="chartPad" :x2="chartPad" :y1="chartPad" :y2="chartHeight - chartPad" class="axis" />
                      <line
                        v-if="hoverX !== null"
                        :x1="hoverX"
                        :x2="hoverX"
                        :y1="chartPad"
                        :y2="chartHeight - chartPad"
                        class="crosshair"
                      />
                      <path :d="series.path" class="trend-line trend-line--sensor" />
                      <circle
                        v-if="hoverX !== null && hoverY(series) !== null"
                        :cx="hoverX"
                        :cy="hoverY(series)!"
                        r="2.7"
                        class="hover-dot hover-dot--sensor"
                      />
                    </svg>
                    <div
                      v-if="hoverMetricKey === series.key && hoverX !== null && hoverValue(series) !== null && hoverCycle !== null"
                      class="chart-tooltip"
                      :style="{ left: `${(hoverX / chartWidth) * 100}%` }"
                    >
                      c{{ hoverCycle }} · {{ hoverValue(series)!.toFixed(2) }}
                    </div>
                  </div>
                  <div class="metric-range">
                    <span>max {{ series.max.toFixed(2) }}</span>
                    <span>min {{ series.min.toFixed(2) }}</span>
                  </div>
                </div>
              </div>
            </section>
            <p class="axis-note">x: cycle · y: value</p>
          </div>
        </div>
      </template>
    </section>
  </div>
</template>

<style scoped>
.engine-detail-page {
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

.panel {
  width: 100%;
  border: 1px solid var(--border);
  border-radius: 12px;
  background: var(--bg);
  padding: 16px;
  margin-bottom: 16px;
}

.panel h2,
.panel h3 {
  margin: 0 0 12px;
}

.detail-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin: 0;
}

.field {
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 10px;
}

.field dt {
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.6px;
  color: var(--text);
  margin-bottom: 4px;
}

.field-title-with-info {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.info-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  border: 1px solid currentColor;
  font-size: 10px;
  font-weight: 700;
  line-height: 1;
  cursor: help;
  opacity: 0.9;
}

.field dd {
  margin: 0;
  color: var(--text-h);
  font-weight: 600;
}

.state {
  font-size: 0.95rem;
  color: var(--text);
}

.state--error {
  color: #e5484d;
  font-weight: 600;
}

.rul-evidence-panel {
  background: #2f343b;
  border-color: #4b5563;
}

.rul-evidence-panel h3 {
  color: #fff;
}

.rul-evidence-panel .field {
  background: rgba(255, 255, 255, 0.08);
  border-color: rgba(255, 255, 255, 0.24);
}

.rul-evidence-panel .field dt,
.rul-evidence-panel .field dd,
.rul-evidence-panel .evidence-sub {
  color: #fff;
}

.evidence-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin: 0;
}

.evidence-field dd {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.evidence-field dd.evidence-value--high,
.evidence-field dd.evidence-value--medium,
.evidence-field dd.evidence-value--low {
  color: #ffffff;
  border-radius: 8px;
  padding: 8px 10px;
}

.evidence-sub {
  font-size: 0.76rem;
  color: var(--text);
  font-weight: 500;
}

.evidence-field--wide {
  grid-column: 1 / -1;
}

.spare-availability-link {
  align-self: center;
  margin-top: 8px;
  border: 1px solid #93c5fd;
  border-radius: 6px;
  background: #2563eb;
  color: #fff;
  padding: 8px 12px;
  font-size: 0.82rem;
  font-weight: 700;
  text-decoration: none;
}

.spare-availability-link:hover {
  background: #1d4ed8;
}

.rul-evidence-panel .field dd.evidence-value--high {
  background: #7a1f1f;
}

.rul-evidence-panel .field dd.evidence-value--medium {
  background: #7a5a12;
}

.rul-evidence-panel .field dd.evidence-value--low {
  background: #1f5f3f;
}

.metric-groups {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.metric-group {
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 6px;
}

.metric-group--op {
  border-color: rgba(37, 99, 235, 0.24);
}

.metric-group--sensor {
  border-color: rgba(22, 163, 74, 0.24);
}

.group-title {
  margin: 0 0 4px;
  font-size: 0.76rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--text);
}

.metric-list {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.metric-row {
  display: grid;
  grid-template-columns: 180px 1fr 120px;
  align-items: center;
  gap: 6px;
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 2px 0;
}

.metric-row--op {
  background: rgba(37, 99, 235, 0.06);
  border-color: rgba(37, 99, 235, 0.28);
}

.metric-row--sensor {
  background: rgba(22, 163, 74, 0.06);
  border-color: rgba(22, 163, 74, 0.28);
}

.metric-name {
  font-size: 0.82rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--text-h);
  font-weight: 700;
}

.metric-chart-wrap {
  position: relative;
  height: 56px;
}

.metric-chart {
  width: 100%;
  height: 100%;
  display: block;
}

.axis {
  stroke: var(--border);
  stroke-width: 1;
}

.crosshair {
  stroke: rgba(120, 120, 120, 0.65);
  stroke-width: 1;
  stroke-dasharray: 3 3;
}

.trend-line {
  fill: none;
  stroke-width: 1.8;
  stroke-linejoin: round;
  stroke-linecap: round;
}

.trend-line--op {
  stroke: #2563eb;
}

.trend-line--sensor {
  stroke: #16a34a;
}

.hover-dot {
  stroke: #fff;
  stroke-width: 1;
}

.hover-dot--op {
  fill: #2563eb;
}

.hover-dot--sensor {
  fill: #16a34a;
}

.chart-tooltip {
  position: absolute;
  bottom: 2px;
  transform: translateX(-50%);
  background: var(--text-h);
  color: var(--bg);
  border-radius: 6px;
  padding: 2px 6px;
  font-size: 0.72rem;
  white-space: nowrap;
  pointer-events: none;
}

.metric-range {
  font-size: 0.74rem;
  color: var(--text);
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.axis-note {
  font-size: 0.78rem;
  color: var(--text);
  margin-top: 6px;
}

@media (max-width: 768px) {
  .engine-detail-page {
    padding: 24px 16px;
  }

  .detail-grid {
    grid-template-columns: 1fr;
  }

  .evidence-grid {
    grid-template-columns: 1fr;
  }

  .metric-row {
    grid-template-columns: 1fr;
  }

  .metric-range {
    grid-column: 1 / -1;
    flex-direction: row;
    justify-content: space-between;
  }
}
</style>
