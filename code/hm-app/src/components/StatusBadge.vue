<script setup lang="ts">
type Status = 'red' | 'yellow' | 'green'

defineProps<{
  label: string
  status: Status
}>()

const icons: Record<Status, string> = {
  red: '🔴',
  yellow: '🟡',
  green: '🟢',
}
</script>

<template>
  <span class="status-badge">
    <span class="status-icon">{{ icons[status] }}</span>
    <span class="status-label">{{ label }}</span>
  </span>
</template>

<style scoped>
.status-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  margin-right: 10px;
  white-space: nowrap;
}

.status-icon {
  font-size: 0.85rem;
}
</style>
