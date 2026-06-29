<script setup lang="ts">
import { useRouter } from 'vue-router'

interface MroFunction {
  id: string
  title: string
  description: string
  icon: string
  aiPowered: boolean
}

const mroFunctions: MroFunction[] = [
  {
    id: 'rul',
    title: 'Remaining Useful Life',
    description: 'AI-driven prediction of component degradation and optimal replacement timing.',
    icon: '⏱️',
    aiPowered: true,
  },
  {
    id: 'spare-parts',
    title: 'Spare Part Supply Optimization',
    description: 'Intelligent inventory forecasting and procurement planning powered by AI.',
    icon: '📦',
    aiPowered: true,
  },
  {
    id: 'easa-docs',
    title: 'EASA Documentation',
    description: 'AI-assisted generation and compliance checking of regulatory documentation.',
    icon: '📋',
    aiPowered: true,
  },
  {
    id: 'work-orders',
    title: 'Work Order Management',
    description: 'Create, assign, and track maintenance work orders across the hangar floor.',
    icon: '🔧',
    aiPowered: false,
  },
  {
    id: 'inspections',
    title: 'Inspection Scheduling',
    description: 'Plan and manage A/B/C/D checks and routine inspection calendars.',
    icon: '🔍',
    aiPowered: false,
  },
  {
    id: 'fleet',
    title: 'Fleet Overview',
    description: 'Real-time status dashboard for all aircraft in the fleet.',
    icon: '✈️',
    aiPowered: false,
  },
  {
    id: 'tooling',
    title: 'Tooling & Equipment',
    description: 'Track calibration status, availability, and allocation of tools and GSE.',
    icon: '🛠️',
    aiPowered: false,
  },
  {
    id: 'personnel',
    title: 'Crew & Certifications',
    description: 'Manage technician qualifications, training records, and shift planning.',
    icon: '👷',
    aiPowered: false,
  },
  {
    id: 'reporting',
    title: 'KPI & Reporting',
    description: 'Track TAT, dispatch reliability, and operational performance metrics.',
    icon: '📊',
    aiPowered: false,
  },
]

const router = useRouter()

function handleClick(fn: MroFunction) {
  if (fn.id === 'rul') {
    router.push({ name: 'rul' })
    return
  }
  if (!fn.aiPowered) {
    alert(`"${fn.title}" is a placeholder module — not yet implemented.`)
  }
}
</script>

<template>
  <div class="app-shell">
    <header class="app-header">
      <div class="brand">
        <span class="logo">✈️</span>
        <h1>Hangar Mind</h1>
      </div>
      <p class="tagline">Intelligent Aircraft Maintenance</p>
    </header>

    <main class="dashboard">
      <section class="section-label ai-section-label">
        <span class="ai-badge">AI</span> AI-Powered Capabilities
      </section>
      <div class="card-grid">
        <button
          v-for="fn in mroFunctions.filter(f => f.aiPowered)"
          :key="fn.id"
          class="card card--ai"
          @click="handleClick(fn)"
        >
          <div class="card-icon">{{ fn.icon }}</div>
          <div class="card-content">
            <h3>{{ fn.title }}</h3>
            <p>{{ fn.description }}</p>
          </div>
          <span class="card-ai-indicator">⚡ AI</span>
        </button>
      </div>

      <section class="section-label">
        Operations & Management
      </section>
      <div class="card-grid">
        <button
          v-for="fn in mroFunctions.filter(f => !f.aiPowered)"
          :key="fn.id"
          class="card"
          @click="handleClick(fn)"
        >
          <div class="card-icon">{{ fn.icon }}</div>
          <div class="card-content">
            <h3>{{ fn.title }}</h3>
            <p>{{ fn.description }}</p>
          </div>
        </button>
      </div>
    </main>
  </div>
</template>

<style scoped>
.app-shell {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.app-header {
  text-align: center;
  padding: 48px 24px 32px;
  border-bottom: 1px solid var(--border);
}

.brand {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
}

.logo {
  font-size: 2.4rem;
}

.brand h1 {
  font-size: 2.4rem;
  margin: 0;
  letter-spacing: -1px;
}

.tagline {
  margin-top: 8px;
  font-size: 1.1rem;
  color: var(--accent);
  font-weight: 500;
}

/* Dashboard */
.dashboard {
  flex: 1;
  max-width: 1100px;
  width: 100%;
  margin: 0 auto;
  padding: 40px 24px;
}

.section-label {
  font-size: 0.85rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 1.2px;
  color: var(--text);
  margin: 32px 0 16px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.section-label:first-child {
  margin-top: 0;
}

.ai-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #aa3bff, #6366f1);
  color: #fff;
  font-size: 0.7rem;
  font-weight: 700;
  padding: 2px 7px;
  border-radius: 4px;
  letter-spacing: 0.5px;
}

/* Card grid */
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 16px;
}

.card {
  all: unset;
  cursor: pointer;
  display: flex;
  align-items: flex-start;
  gap: 16px;
  padding: 24px;
  border-radius: 12px;
  border: 1px solid var(--border);
  background: var(--bg);
  transition: box-shadow 0.25s, border-color 0.25s, transform 0.15s;
  position: relative;
  box-sizing: border-box;
}

.card:hover {
  box-shadow: var(--shadow);
  transform: translateY(-2px);
}

.card:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}

.card--ai {
  border-color: var(--accent-border);
  background: var(--accent-bg);
}

.card--ai:hover {
  border-color: var(--accent);
  box-shadow: 0 8px 24px rgba(170, 59, 255, 0.18), var(--shadow);
}

.card-icon {
  font-size: 2rem;
  flex-shrink: 0;
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 10px;
  background: var(--social-bg);
}

.card--ai .card-icon {
  background: rgba(170, 59, 255, 0.15);
}

.card-content h3 {
  font-size: 1rem;
  font-weight: 600;
  color: var(--text-h);
  margin: 0 0 6px;
}

.card-content p {
  font-size: 0.88rem;
  line-height: 1.5;
  color: var(--text);
  margin: 0;
}

.card-ai-indicator {
  position: absolute;
  top: 12px;
  right: 12px;
  font-size: 0.72rem;
  font-weight: 700;
  color: var(--accent);
  background: var(--accent-bg);
  padding: 2px 8px;
  border-radius: 6px;
  border: 1px solid var(--accent-border);
}

@media (max-width: 768px) {
  .card-grid {
    grid-template-columns: 1fr;
  }
  .brand h1 {
    font-size: 1.8rem;
  }
  .app-header {
    padding: 32px 16px 24px;
  }
  .dashboard {
    padding: 24px 16px;
  }
}
</style>
