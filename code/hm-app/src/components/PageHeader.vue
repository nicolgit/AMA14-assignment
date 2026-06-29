<script setup lang="ts">
import { useRouter } from 'vue-router'

defineProps<{ title: string }>()

const router = useRouter()
</script>

<template>
  <header class="page-header">
    <button class="back-btn" @click="router.push({ name: 'home' })">
      ← Back
    </button>
    <nav class="breadcrumb">
      <span class="crumb-home">✈️ Hangar Mind</span>
      <span class="sep">›</span>
      <span class="crumb-current">{{ title }}</span>
    </nav>
  </header>
</template>

<style scoped>
.page-header {
  display: flex;
  align-items: center;
  gap: 16px;
}

.back-btn {
  background: var(--accent-bg);
  color: var(--accent);
  border: 1px solid var(--accent-border);
  border-radius: 8px;
  padding: 8px 16px;
  cursor: pointer;
  font-size: 0.95rem;
  font-weight: 600;
  transition: filter 0.2s;
  flex-shrink: 0;
}

.back-btn:hover {
  filter: brightness(1.2);
}

.breadcrumb {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 1.1rem;
}

.crumb-home {
  font-weight: 600;
}

.sep {
  color: var(--text);
  opacity: 0.6;
}

.crumb-current {
  font-weight: 700;
  color: var(--text-h);
}
</style>
