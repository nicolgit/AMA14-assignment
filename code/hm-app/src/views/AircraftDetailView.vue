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

const route = useRoute()

const loading = ref(false)
const error = ref('')
const aircraft = ref<Aircraft | null>(null)
const location = ref<Location | null>(null)

const aircraftId = computed(() => String(route.params.aircraftid ?? ''))

const engineTags = computed(() =>
  (aircraft.value?.engine_ids?.split(';') ?? [])
    .map((id) => id.trim())
    .filter(Boolean),
)

const baseLocationDisplay = computed(() => {
  if (location.value) {
    return `${location.value.location_code} - ${location.value.location_name} - ${location.value.place}`
  }
  return aircraft.value?.base_location ?? '—'
})

async function loadAircraft() {
  if (!aircraftId.value) {
    error.value = 'Missing aircraft id.'
    return
  }

  loading.value = true
  error.value = ''
  aircraft.value = null
  location.value = null

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
              <dt>Engine IDs</dt>
              <dd>
                <template v-if="engineTags.length > 0">
                  <StatusBadge
                    v-for="eng in engineTags"
                    :key="eng"
                    :label="eng"
                    status="green"
                  />
                </template>
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