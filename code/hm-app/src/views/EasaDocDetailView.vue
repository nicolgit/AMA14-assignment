<script setup lang="ts">
import { ref, onMounted } from 'vue'
import PageHeader from '../components/PageHeader.vue'
import { API_BASE_URL } from '../config'

const props = defineProps<{ docid: string }>()

interface KbDocument {
  document_id: string
  title: string
  type: string | null
  revision: string | null
  date: string | null
  storage_uri: string | null
  status: string | null
}

const doc = ref<KbDocument | null>(null)
const content = ref('')
const loading = ref(false)
const error = ref('')

async function loadDocument() {
  loading.value = true
  error.value = ''
  try {
    const [metaRes, blobRes] = await Promise.all([
      fetch(`${API_BASE_URL}/v1/doc/${encodeURIComponent(props.docid)}`),
      fetch(`${API_BASE_URL}/v1/doc/${encodeURIComponent(props.docid)}/blob`),
    ])

    for (const res of [metaRes, blobRes]) {
      if (!res.ok) {
        let detail = `HTTP ${res.status}`
        try {
          const body = await res.clone().json()
          if (body?.detail) detail = body.detail
        } catch {
          /* response had no JSON body */
        }
        throw new Error(detail)
      }
    }

    doc.value = await metaRes.json()
    content.value = await blobRes.text()
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
}

onMounted(loadDocument)
</script>

<template>
  <div class="doc-page">
    <PageHeader
      :title="doc?.document_id ?? docid"
      rootLabel="EASA Documentation"
      :rootTo="{ name: 'easa-docs' }"
    />

    <section class="content">
      <p v-if="loading" class="state">Loading document…</p>
      <p v-else-if="error" class="state state--error">⚠️ {{ error }}</p>

      <template v-else>
        <header v-if="doc" class="doc-meta">
          <h2 class="doc-title">{{ doc.title }}</h2>
          <div class="meta-row">
            <span class="meta-item"><span class="meta-label">Type</span>{{ doc.type }}</span>
            <span class="meta-item"><span class="meta-label">Revision</span>{{ doc.revision }}</span>
            <span class="meta-item"><span class="meta-label">Date</span>{{ doc.date }}</span>
            <span class="meta-item"><span class="meta-label">Status</span>{{ doc.status }}</span>
          </div>
          <p class="meta-uri">{{ doc.storage_uri }}</p>
        </header>

        <!-- Markdown shown as plain text for the PoC (no rendering library yet). -->
        <pre class="doc-content">{{ content }}</pre>
      </template>
    </section>
  </div>
</template>

<style scoped>
.doc-page {
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

.doc-meta {
  margin-bottom: 20px;
}

.doc-title {
  font-size: 1.3rem;
  color: var(--text-h);
  margin: 0 0 12px;
}

.meta-row {
  display: flex;
  flex-wrap: wrap;
  gap: 20px;
  margin-bottom: 8px;
}

.meta-item {
  display: inline-flex;
  align-items: baseline;
  gap: 8px;
  font-size: 0.9rem;
  color: var(--text-h);
}

.meta-label {
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: var(--accent);
}

.meta-uri {
  font-size: 0.8rem;
  color: var(--text);
  margin: 0;
  word-break: break-all;
}

.doc-content {
  width: 100%;
  box-sizing: border-box;
  margin: 0;
  padding: 20px;
  border: 1px solid var(--border);
  border-radius: 12px;
  background: var(--social-bg);
  color: var(--text-h);
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.85rem;
  line-height: 1.5;
  white-space: pre-wrap;
  word-wrap: break-word;
  overflow-x: auto;
}

@media (max-width: 768px) {
  .doc-page {
    padding: 16px;
  }
}
</style>
