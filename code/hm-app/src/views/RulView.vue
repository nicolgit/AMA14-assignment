<script setup lang="ts">
import PageHeader from '../components/PageHeader.vue'
</script>

<template>
  <div class="rul-page">
    <PageHeader title="Remaining Useful Life" />
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
</style>
