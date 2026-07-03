<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { API_BASE_URL } from './config'

const backendOk = ref(false)
const backendError = ref('')
let pingTimer: number | undefined

async function checkBackend() {
  try {
    const res = await fetch(`${API_BASE_URL}/v1/db/ping`)
    if (!res.ok) {
      let detail = `HTTP ${res.status}`
      try {
        const body = await res.json()
        if (body?.detail) detail = body.detail
      } catch {
        /* response had no JSON body */
      }
      backendOk.value = false
      backendError.value = detail
      return
    }
    backendOk.value = true
    backendError.value = ''
  } catch (err) {
    backendOk.value = false
    backendError.value = err instanceof Error ? err.message : String(err)
  }
}

onMounted(() => {
  checkBackend()
  pingTimer = window.setInterval(checkBackend, 10_000)
})

onUnmounted(() => {
  if (pingTimer !== undefined) window.clearInterval(pingTimer)
})
</script>

<template>
  <div class="app-root">
    <header class="app-topbar">
      <p class="backend-status">
        <span v-if="backendOk">🟢 backend ok</span>
        <span v-else>🔴 backend error - {{ backendError }}</span>
      </p>
    </header>

    <router-view />
  </div>
</template>

<style scoped>
.app-root {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.app-root > :first-child {
  flex: 0 1 auto;
}

.app-topbar {
  text-align: center;
  padding: 10px 16px;
  border-bottom: 1px solid var(--border);
  background: color-mix(in oklab, var(--card-bg) 92%, var(--accent-bg));
}

.backend-status {
  margin: 0;
  font-size: 0.82rem;
  font-weight: 600;
  color: var(--text);
}

.app-root > :last-child {
  text-align: center;
  flex: 1;
}
</style>
