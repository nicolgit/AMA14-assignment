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
    <router-view />

    <footer class="app-footer">
      <p class="backend-status">Hangar Mind v0.1 — MRO Intelligence Platform — 
        <span v-if="backendOk">🟢 backend ok</span>
        <span v-else>🔴 backend error - {{ backendError }}</span>
      </p>
    </footer>
  </div>
</template>

<style scoped>
.app-root {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.app-root > :first-child {
  flex: 1;
}

.app-footer {
  text-align: center;
  padding: 24px;
  border-top: 1px solid var(--border);
  font-size: 0.82rem;
  color: var(--text);
}

.backend-status {
  margin-top: 6px;
  font-size: 0.78rem;
  font-weight: 600;
}
</style>
