<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
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

interface Evaluation {
  name: string
  value: number
}

const aircraft = ref<Aircraft[]>([])
const evaluations = ref<Evaluation[]>([])
const loading = ref(false)
const error = ref('')

const pageSize = 10
const currentPage = ref(1)

const totalPages = computed(() =>
  Math.max(1, Math.ceil(aircraft.value.length / pageSize)),
)

const pagedAircraft = computed(() => {
  const start = (currentPage.value - 1) * pageSize
  return aircraft.value.slice(start, start + pageSize)
})

function prevPage() {
  if (currentPage.value > 1) currentPage.value--
}

function nextPage() {
  if (currentPage.value < totalPages.value) currentPage.value++
}

async function loadAircraft() {
  loading.value = true
  error.value = ''
  try {
    const [acRes, evalRes] = await Promise.all([
      fetch(`${API_BASE_URL}/v1/aircraft`),
      fetch(`${API_BASE_URL}/v1/evaluations`),
    ])
    for (const res of [acRes, evalRes]) {
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
    }
    aircraft.value = await acRes.json()
    evaluations.value = await evalRes.json()
    currentPage.value = 1
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
}

onMounted(loadAircraft)
</script>

<template>
  <div class="rul-page">
    <PageHeader title="Remaining Useful Life" />

    <section class="content">
      <p v-if="loading" class="state">Loading aircraft…</p>
      <p v-else-if="error" class="state state--error">⚠️ {{ error }}</p>
      <p v-else-if="aircraft.length === 0" class="state">No aircraft found.</p>

      <template v-else>
        <div class="metrics-row">
          <span v-for="ev in evaluations" :key="ev.name" class="metric">
            <span class="metric-name">{{ ev.name.toUpperCase() }}</span>
            <span class="metric-value">{{ ev.value.toFixed(2) }}</span>
          </span>
        </div>

        <table class="aircraft-table">
          <thead>
            <tr>
              <th>Aircraft ID</th>
              <th>Model</th>
              <th>Operator</th>
              <th>Engines</th>
              <th>Status</th>
              <th>Flight Cycles</th>
              <th>Flight Hours</th>
              <th>Base</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="ac in pagedAircraft" :key="ac.aircraft_id">
              <td>{{ ac.aircraft_id }}</td>
              <td>{{ ac.model }}</td>
              <td>{{ ac.operator }}</td>
              <td>
                <StatusBadge
                  v-for="eng in (ac.engine_ids?.split(';') ?? [])"
                  :key="eng"
                  :label="eng.trim()"
                  status="green"
                />
              </td>
              <td>{{ ac.status }}</td>
              <td>{{ ac.total_flight_cycles }}</td>
              <td>{{ ac.total_flight_hours }}</td>
              <td>{{ ac.base_location }}</td>
            </tr>
          </tbody>
        </table>

        <nav class="pager">
          <button class="pager-btn" :disabled="currentPage === 1" @click="prevPage">
            ‹ Prev
          </button>
          <span class="pager-info">Page {{ currentPage }} of {{ totalPages }}</span>
          <button
            class="pager-btn"
            :disabled="currentPage === totalPages"
            @click="nextPage"
          >
            Next ›
          </button>
        </nav>
      </template>
    </section>
  </div>
</template>

<style scoped>
.rul-page {
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

.metrics-row {
  display: flex;
  gap: 24px;
  margin-bottom: 20px;
}

.metric {
  display: inline-flex;
  align-items: baseline;
  gap: 8px;
  padding: 10px 16px;
  border: 1px solid var(--accent-border);
  background: var(--accent-bg);
  border-radius: 10px;
}

.metric-name {
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.6px;
  color: var(--accent);
}

.metric-value {
  font-size: 1.1rem;
  font-weight: 700;
  color: var(--text-h);
}

.aircraft-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.88rem;
}

.aircraft-table th,
.aircraft-table td {
  text-align: left;
  padding: 10px 14px;
  border-bottom: 1px solid var(--border);
}

.aircraft-table th {
  font-weight: 600;
  color: var(--text-h);
  text-transform: uppercase;
  font-size: 0.72rem;
  letter-spacing: 0.6px;
}

.aircraft-table tbody tr:hover {
  background: var(--accent-bg);
}

.pager {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-top: 20px;
}

.pager-btn {
  background: var(--accent-bg);
  color: var(--accent);
  border: 1px solid var(--accent-border);
  border-radius: 8px;
  padding: 6px 14px;
  cursor: pointer;
  font-size: 0.9rem;
  font-weight: 600;
  transition: filter 0.2s;
}

.pager-btn:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.pager-btn:not(:disabled):hover {
  filter: brightness(1.2);
}

.pager-info {
  font-size: 0.85rem;
  color: var(--text);
}
</style>
