<script setup lang="ts">
import { useRouter } from 'vue-router'
import type { RouteLocationRaw } from 'vue-router'

const props = defineProps<{
  title: string
  rootLabel?: string
  rootTo?: RouteLocationRaw
}>()

const router = useRouter()

function goBack() {
  router.back()
}
</script>

<template>
  <header class="page-header">
    <button class="back-btn" @click="goBack">
      ← Back
    </button>
    <nav class="breadcrumb">
      <router-link :to="{ name: 'home' }" replace class="crumb-home crumb-link">
        ✈️ Hangar Mind
      </router-link>

      <template v-if="props.rootLabel">
        <span class="sep">›</span>
        <router-link v-if="props.rootTo" :to="props.rootTo" class="crumb-home crumb-link">
          {{ props.rootLabel }}
        </router-link>
        <span v-else class="crumb-home">{{ props.rootLabel }}</span>
      </template>

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

.crumb-link {
  color: var(--accent);
  text-decoration: none;
}

.crumb-link:hover {
  text-decoration: underline;
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
