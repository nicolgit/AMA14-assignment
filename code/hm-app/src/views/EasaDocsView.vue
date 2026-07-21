<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import PageHeader from '../components/PageHeader.vue'
// import { API_BASE_URL } from '../config'

interface KbDocument {
  doc_id: string
  title: string
  doc_type: 'AMM' | 'SRM' | 'CMM' | 'AD' | 'SB' | 'Task Card'
  ata_chapter: string | null
  revision: string | null
  effective_date: string | null
  source_file: string | null
  status: 'indexed' | 'processing' | 'failed'
}

const documents = ref<KbDocument[]>([])
const loading = ref(false)
const error = ref('')

const searchQuery = ref('')

const pageSize = 10
const currentPage = ref(1)

const filteredDocuments = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return documents.value
  return documents.value.filter((d) =>
    [d.doc_id, d.title, d.doc_type, d.ata_chapter, d.revision, d.source_file]
      .filter(Boolean)
      .some((field) => String(field).toLowerCase().includes(q)),
  )
})

const totalPages = computed(() =>
  Math.max(1, Math.ceil(filteredDocuments.value.length / pageSize)),
)

const pagedDocuments = computed(() => {
  const start = (currentPage.value - 1) * pageSize
  return filteredDocuments.value.slice(start, start + pageSize)
})

function prevPage() {
  if (currentPage.value > 1) currentPage.value--
}

function nextPage() {
  if (currentPage.value < totalPages.value) currentPage.value++
}

function runSearch() {
  // AI-assisted search will be wired to the engineering RAG endpoint later.
  currentPage.value = 1
}

function toggleMic() {
  // Voice input placeholder — no behaviour yet.
}

const FAKE_DOCUMENTS: KbDocument[] = [
  {
    doc_id: 'AMM-72-00-00',
    title: 'Engine — General, Description and Operation',
    doc_type: 'AMM',
    ata_chapter: '72-00',
    revision: 'Rev 42',
    effective_date: '2025-11-01',
    source_file: 'AMM-Aircraft-maintenance-manual-sample-amm-engine.pdf',
    status: 'indexed',
  },
  {
    doc_id: 'AMM-72-30-00',
    title: 'Compressor Section — Removal / Installation',
    doc_type: 'AMM',
    ata_chapter: '72-30',
    revision: 'Rev 42',
    effective_date: '2025-11-01',
    source_file: 'amm-72-30-compressor.pdf',
    status: 'indexed',
  },
  {
    doc_id: 'SRM-53-10-01',
    title: 'Fuselage Skin Repair — Allowable Damage',
    doc_type: 'SRM',
    ata_chapter: '53-10',
    revision: 'Rev 18',
    effective_date: '2025-06-15',
    source_file: 'srm-53-10-skin.pdf',
    status: 'indexed',
  },
  {
    doc_id: 'CMM-32-41-07',
    title: 'Brake Control Unit — Component Maintenance',
    doc_type: 'CMM',
    ata_chapter: '32-41',
    revision: 'Rev 9',
    effective_date: '2024-12-02',
    source_file: 'cmm-32-41-bcu.pdf',
    status: 'indexed',
  },
  {
    doc_id: 'AD-2025-0142',
    title: 'Airworthiness Directive — HP Turbine Blade Inspection',
    doc_type: 'AD',
    ata_chapter: '72-50',
    revision: 'Initial',
    effective_date: '2025-09-20',
    source_file: 'ad-2025-0142.pdf',
    status: 'indexed',
  },
  {
    doc_id: 'SB-72-A0231',
    title: 'Service Bulletin — Fuel Nozzle Upgrade',
    doc_type: 'SB',
    ata_chapter: '72-40',
    revision: 'Rev 2',
    effective_date: '2025-03-10',
    source_file: 'sb-72-a0231.pdf',
    status: 'processing',
  },
  {
    doc_id: 'TC-0001',
    title: 'Task Card — Borescope Inspection HP Compressor',
    doc_type: 'Task Card',
    ata_chapter: '72-30',
    revision: 'Rev 3',
    effective_date: '2025-08-01',
    source_file: 'task-card-0001.md',
    status: 'indexed',
  },
  {
    doc_id: 'TC-0002',
    title: 'Task Card — Fan Blade Lubrication',
    doc_type: 'Task Card',
    ata_chapter: '72-20',
    revision: 'Rev 1',
    effective_date: '2025-07-11',
    source_file: 'task-card-0002.md',
    status: 'indexed',
  },
  {
    doc_id: 'TC-0003',
    title: 'Task Card — Oil System Filter Replacement',
    doc_type: 'Task Card',
    ata_chapter: '79-20',
    revision: 'Rev 5',
    effective_date: '2025-05-22',
    source_file: 'task-card-0003.md',
    status: 'indexed',
  },
  {
    doc_id: 'TC-0004',
    title: 'Task Card — EGT Sensor Functional Check',
    doc_type: 'Task Card',
    ata_chapter: '77-20',
    revision: 'Rev 2',
    effective_date: '2025-04-18',
    source_file: 'task-card-0004.md',
    status: 'indexed',
  },
  {
    doc_id: 'TC-0005',
    title: 'Task Card — Igniter Plug Continuity Test',
    doc_type: 'Task Card',
    ata_chapter: '74-20',
    revision: 'Rev 1',
    effective_date: '2025-02-05',
    source_file: 'task-card-0005.md',
    status: 'failed',
  },
  {
    doc_id: 'CMM-24-31-02',
    title: 'Generator Control Unit — Component Maintenance',
    doc_type: 'CMM',
    ata_chapter: '24-31',
    revision: 'Rev 6',
    effective_date: '2024-10-14',
    source_file: 'cmm-24-31-gcu.pdf',
    status: 'indexed',
  },
]

async function loadDocuments() {
  loading.value = true
  error.value = ''
  try {
    // TODO: replace with real call, e.g.
    // const res = await fetch(`${API_BASE_URL}/v1/engineering/documents`)
    // documents.value = await res.json()
    await new Promise((resolve) => setTimeout(resolve, 300))
    documents.value = FAKE_DOCUMENTS
    currentPage.value = 1
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
}

function docTypeClass(type: KbDocument['doc_type']): string {
  return `doc-type doc-type--${type.replace(/\s+/g, '').toLowerCase()}`
}

onMounted(loadDocuments)
</script>

<template>
  <div class="easa-page">
    <PageHeader title="EASA Documentation" />

    <section class="search-panel">
      <h2 class="search-title">
        <span class="ai-badge">AI</span> Assisted Documentation Search
      </h2>
      <p class="search-sub">
        Ask a question about AMM, SRM, CMM, AD, SB procedures or historical task cards.
      </p>
      <div class="search-bar">
        <span class="search-icon">🔎</span>
        <input
          v-model="searchQuery"
          class="search-input"
          type="text"
          placeholder="e.g. borescope inspection procedure for HP compressor"
          @keyup.enter="runSearch"
        />
        <button class="mic-btn" title="Voice input (coming soon)" @click="toggleMic">
          🎙️
        </button>
        <button class="search-btn" @click="runSearch">Search</button>
      </div>
    </section>

    <section class="content">
      <div class="content-head">
        <h3 class="content-title">Knowledge Base Documents</h3>
        <span class="content-count">{{ filteredDocuments.length }} documents</span>
      </div>

      <p v-if="loading" class="state">Loading documents…</p>
      <p v-else-if="error" class="state state--error">⚠️ {{ error }}</p>
      <p v-else-if="filteredDocuments.length === 0" class="state">No documents found.</p>

      <template v-else>
        <table class="docs-table">
          <thead>
            <tr>
              <th>Document ID</th>
              <th>Title</th>
              <th>Type</th>
              <th>ATA</th>
              <th>Revision</th>
              <th>Effective Date</th>
              <th>Source</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="doc in pagedDocuments" :key="doc.doc_id">
              <td class="doc-id">{{ doc.doc_id }}</td>
              <td>{{ doc.title }}</td>
              <td><span :class="docTypeClass(doc.doc_type)">{{ doc.doc_type }}</span></td>
              <td>{{ doc.ata_chapter }}</td>
              <td>{{ doc.revision }}</td>
              <td>{{ doc.effective_date }}</td>
              <td class="doc-source">{{ doc.source_file }}</td>
              <td>
                <span :class="`status-pill status-pill--${doc.status}`">
                  {{ doc.status }}
                </span>
              </td>
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
.easa-page {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 24px;
  padding: 32px;
}

/* Search panel */
.search-panel {
  width: 100%;
  padding: 24px;
  border: 1px solid var(--accent-border);
  background: var(--accent-bg);
  border-radius: 12px;
  box-sizing: border-box;
}

.search-title {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 1.1rem;
  margin: 0 0 6px;
  color: var(--text-h);
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

.search-sub {
  margin: 0 0 16px;
  font-size: 0.9rem;
  color: var(--text);
}

.search-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 999px;
  padding: 6px 6px 6px 16px;
}

.search-icon {
  font-size: 1rem;
  flex-shrink: 0;
}

.search-input {
  flex: 1;
  border: none;
  background: transparent;
  outline: none;
  font-size: 0.95rem;
  color: var(--text-h);
  padding: 8px 0;
}

.mic-btn {
  border: 1px solid var(--border);
  background: var(--bg);
  border-radius: 999px;
  width: 40px;
  height: 40px;
  font-size: 1.1rem;
  cursor: pointer;
  flex-shrink: 0;
  transition: filter 0.2s, border-color 0.2s;
}

.mic-btn:hover {
  border-color: var(--accent);
  filter: brightness(1.05);
}

.search-btn {
  border: 1px solid var(--accent-border);
  background: var(--accent);
  color: #fff;
  border-radius: 999px;
  padding: 9px 20px;
  font-weight: 700;
  cursor: pointer;
  flex-shrink: 0;
}

.search-btn:hover {
  filter: brightness(1.05);
}

/* Content */
.content {
  width: 100%;
}

.content-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: 16px;
}

.content-title {
  font-size: 1rem;
  color: var(--text-h);
  margin: 0;
}

.content-count {
  font-size: 0.85rem;
  color: var(--text);
}

.state {
  font-size: 0.95rem;
  color: var(--text);
}

.state--error {
  color: #e5484d;
  font-weight: 600;
}

.docs-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.88rem;
}

.docs-table th,
.docs-table td {
  text-align: left;
  padding: 10px 14px;
  border-bottom: 1px solid var(--border);
}

.docs-table th {
  font-weight: 600;
  color: var(--text-h);
  text-transform: uppercase;
  font-size: 0.72rem;
  letter-spacing: 0.6px;
}

.docs-table tbody tr:hover {
  background: var(--accent-bg);
}

.doc-id {
  font-weight: 600;
  color: var(--accent);
  white-space: nowrap;
}

.doc-source {
  color: var(--text);
  font-size: 0.82rem;
}

.doc-type {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 6px;
  font-size: 0.72rem;
  font-weight: 700;
  border: 1px solid var(--border);
  background: var(--social-bg);
  color: var(--text-h);
}

.doc-type--ad {
  border-color: #e5484d;
  color: #e5484d;
  background: rgba(229, 72, 77, 0.1);
}

.doc-type--sb {
  border-color: #f5a623;
  color: #b57400;
  background: rgba(245, 166, 35, 0.12);
}

.doc-type--taskcard {
  border-color: var(--accent-border);
  color: var(--accent);
  background: var(--accent-bg);
}

.status-pill {
  display: inline-block;
  padding: 2px 10px;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: capitalize;
}

.status-pill--indexed {
  color: #1a7f37;
  background: rgba(26, 127, 55, 0.12);
}

.status-pill--processing {
  color: #b57400;
  background: rgba(245, 166, 35, 0.12);
}

.status-pill--failed {
  color: #e5484d;
  background: rgba(229, 72, 77, 0.12);
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
  padding: 8px 16px;
  cursor: pointer;
  font-weight: 600;
}

.pager-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.pager-info {
  font-size: 0.88rem;
  color: var(--text);
}

@media (max-width: 768px) {
  .easa-page {
    padding: 16px;
  }
  .search-bar {
    flex-wrap: wrap;
    border-radius: 12px;
  }
  .search-input {
    min-width: 0;
  }
}
</style>
