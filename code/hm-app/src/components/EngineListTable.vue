<script setup lang="ts">
import StatusBadge from './StatusBadge.vue'

type BadgeStatus = 'red' | 'yellow' | 'green'

interface EngineRow {
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

const props = withDefaults(
  defineProps<{
    engines: EngineRow[]
    aircraftId?: string
    urgencyByEngineId?: Record<string, number>
    healthByEngineId?: Record<string, EngineHealth>
    showHealthColumns?: boolean
    selectable?: boolean
    selectedEngineId?: string | null
    emptyLabel?: string
  }>(),
  {
    aircraftId: '',
    urgencyByEngineId: () => ({}),
    healthByEngineId: () => ({}),
    showHealthColumns: false,
    selectable: false,
    selectedEngineId: null,
    emptyLabel: '—',
  },
)

const emit = defineEmits<{
  (event: 'select-engine', engineId: string): void
}>()

function statusForUrgencyLevel(level?: number): BadgeStatus {
  if (level === 3) return 'red'
  if (level === 2) return 'yellow'
  return 'green'
}

function engineBadgeStatus(engineTag: string): BadgeStatus {
  return statusForUrgencyLevel(props.urgencyByEngineId[engineTag])
}

function formatRul(engineId: string): string {
  const value = props.healthByEngineId[engineId]?.predicted_rul
  return value === null || value === undefined ? 'N/A' : value.toFixed(2)
}

function formatRisk(engineId: string): string {
  const value = props.healthByEngineId[engineId]?.risk_30
  return value === null || value === undefined ? 'N/A' : `${(value * 100).toFixed(2)}%`
}

function isSelected(engineId: string): boolean {
  return props.selectedEngineId === engineId
}

function selectEngine(engineId: string) {
  if (!props.selectable) return
  emit('select-engine', engineId)
}
</script>

<template>
  <table v-if="props.engines.length > 0" class="engine-table">
    <thead>
      <tr>
        <th>Engine ID</th>
        <th>Manufacturer</th>
        <th>Serial Number</th>
        <th>Position</th>
        <th>Installation Date</th>
        <th v-if="props.showHealthColumns">RUL</th>
        <th v-if="props.showHealthColumns">Risk 30</th>
      </tr>
    </thead>
    <tbody>
      <tr
        v-for="eng in props.engines"
        :key="eng.engineid"
        :class="{ 'engine-row--selected': isSelected(eng.engineid), 'engine-row--selectable': props.selectable }"
        @click="selectEngine(eng.engineid)"
        @keydown.enter.prevent="selectEngine(eng.engineid)"
        @keydown.space.prevent="selectEngine(eng.engineid)"
        :tabindex="props.selectable ? 0 : undefined"
        role="button"
      >
        <td>
          <div class="engine-id-cell">
            <StatusBadge :label="''" :status="engineBadgeStatus(eng.engineid)" />
            <router-link
              v-if="props.aircraftId"
              class="engine-link"
              :to="{ name: 'engine-detail', params: { aircraftid: props.aircraftId, engineid: eng.engineid } }"
            >
              {{ eng.engineid }}
            </router-link>
            <span v-else>{{ eng.engineid }}</span>
          </div>
        </td>
        <td>{{ eng.manifacturer ?? '—' }}</td>
        <td>{{ eng.engine_serial_number ?? '—' }}</td>
        <td>{{ eng.position_on_iarcraft ?? '—' }}</td>
        <td>{{ eng.installation_date ?? '—' }}</td>
        <td v-if="props.showHealthColumns">{{ formatRul(eng.engineid) }}</td>
        <td v-if="props.showHealthColumns">{{ formatRisk(eng.engineid) }}</td>
      </tr>
    </tbody>
  </table>
  <span v-else>{{ props.emptyLabel }}</span>
</template>

<style scoped>
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

.engine-row--selectable {
  cursor: pointer;
}

.engine-row--selected {
  background: color-mix(in oklab, var(--accent-bg) 55%, transparent);
}

.engine-row--selected .engine-id-cell::before {
  content: '•';
  color: var(--accent);
  font-size: 1.1rem;
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
</style>
