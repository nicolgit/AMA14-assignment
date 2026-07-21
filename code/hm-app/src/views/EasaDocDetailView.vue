<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import PageHeader from '../components/PageHeader.vue'
import MarkdownViewer from '../components/MarkdownViewer.vue'
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

// Edit mode is only offered for draft documents. `editContent` holds the
// working copy shown in the textarea while editing.
const editing = ref(false)
const editContent = ref('')
const editTitle = ref('')
const saving = ref(false)
const publishing = ref(false)
const saveError = ref('')

const isDraft = computed(() => (doc.value?.status ?? '').trim().toLowerCase() === 'draft')

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

function startEdit() {
  saveError.value = ''
  editContent.value = content.value
  editTitle.value = doc.value?.title ?? ''
  editing.value = true
}

function cancelEdit() {
  editing.value = false
  saveError.value = ''
}

async function saveEdit() {
  saving.value = true
  saveError.value = ''
  try {
    const res = await fetch(
      `${API_BASE_URL}/v1/doc/${encodeURIComponent(props.docid)}/blob`,
      {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content: editContent.value, title: editTitle.value }),
      },
    )
    if (!res.ok) {
      let detail = `HTTP ${res.status}`
      try {
        const body = await res.json()
        if (body?.detail) detail = body.detail
      } catch {
        /* response had no JSON body */
      }
      throw new Error(detail)
    }
    content.value = editContent.value
    if (doc.value) doc.value.title = editTitle.value.trim() || doc.value.title
    editing.value = false
  } catch (err) {
    saveError.value = err instanceof Error ? err.message : String(err)
  } finally {
    saving.value = false
  }
}

async function publishEdit() {
  if (!window.confirm('Save and publish this document? Its status will change to "published".')) {
    return
  }
  publishing.value = true
  saveError.value = ''
  try {
    const res = await fetch(
      `${API_BASE_URL}/v1/doc/${encodeURIComponent(props.docid)}/blob`,
      {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          content: editContent.value,
          title: editTitle.value,
          status: 'published',
        }),
      },
    )
    if (!res.ok) {
      let detail = `HTTP ${res.status}`
      try {
        const body = await res.json()
        if (body?.detail) detail = body.detail
      } catch {
        /* response had no JSON body */
      }
      throw new Error(detail)
    }
    content.value = editContent.value
    if (doc.value) {
      doc.value.title = editTitle.value.trim() || doc.value.title
      doc.value.status = 'published'
    }
    editing.value = false
  } catch (err) {
    saveError.value = err instanceof Error ? err.message : String(err)
  } finally {
    publishing.value = false
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
          <div class="doc-title-row">
            <h2 class="doc-title">{{ doc.title }}</h2>
            <button
              v-if="isDraft && !editing"
              class="edit-btn"
              type="button"
              @click="startEdit"
            >
              ✏️ Edit
            </button>
          </div>
          <div class="meta-row">
            <span class="meta-item"><span class="meta-label">Type</span>{{ doc.type }}</span>
            <span class="meta-item"><span class="meta-label">Revision</span>{{ doc.revision }}</span>
            <span class="meta-item"><span class="meta-label">Date</span>{{ doc.date }}</span>
            <span class="meta-item"><span class="meta-label">Status</span>{{ doc.status }}</span>
          </div>
          <p class="meta-uri">{{ doc.storage_uri }}</p>
        </header>

        <template v-if="editing">
          <label class="edit-field">
            <span class="edit-label">Title</span>
            <input v-model="editTitle" class="doc-title-input" type="text" />
          </label>
          <textarea v-model="editContent" class="doc-editor" spellcheck="false"></textarea>
          <p v-if="saveError" class="state state--error">⚠️ {{ saveError }}</p>
          <div class="edit-actions">
            <button class="save-btn" type="button" :disabled="saving || publishing" @click="saveEdit">
              {{ saving ? 'Saving…' : '💾 Save' }}
            </button>
            <button
              class="publish-btn"
              type="button"
              :disabled="saving || publishing"
              @click="publishEdit"
            >
              {{ publishing ? 'Publishing…' : '🚀 Publish' }}
            </button>
            <button class="cancel-btn" type="button" :disabled="saving || publishing" @click="cancelEdit">
              Cancel
            </button>
          </div>
        </template>

        <MarkdownViewer v-else :source="content" class="doc-content" />
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

.doc-title-row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.edit-btn,
.save-btn,
.cancel-btn {
  border-radius: 8px;
  padding: 8px 14px;
  font-size: 0.85rem;
  font-weight: 700;
  cursor: pointer;
  white-space: nowrap;
}

.edit-btn {
  border: 1px solid var(--accent-border);
  background: var(--accent-bg);
  color: var(--accent);
}

.edit-btn:hover {
  filter: brightness(1.05);
}

.doc-editor {
  width: 100%;
  min-height: 60vh;
  box-sizing: border-box;
  padding: 16px;
  border: 1px solid var(--border);
  border-radius: 12px;
  background: var(--bg);
  color: var(--text-h);
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.85rem;
  line-height: 1.5;
  resize: vertical;
}

.edit-field {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-bottom: 12px;
}

.edit-label {
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: var(--accent);
}

.doc-title-input {
  width: 100%;
  box-sizing: border-box;
  padding: 10px 12px;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--bg);
  color: var(--text-h);
  font-size: 1rem;
}

.edit-actions {
  display: flex;
  gap: 12px;
  margin-top: 12px;
}

.save-btn {
  border: none;
  color: #fff;
  background: var(--accent);
}

.save-btn:hover:not(:disabled) {
  filter: brightness(1.08);
}

.publish-btn {
  border: none;
  border-radius: 8px;
  padding: 8px 14px;
  font-size: 0.85rem;
  font-weight: 700;
  cursor: pointer;
  white-space: nowrap;
  color: #fff;
  background: #2e7d32;
}

.publish-btn:hover:not(:disabled) {
  filter: brightness(1.08);
}

.cancel-btn {
  border: 1px solid var(--border);
  background: transparent;
  color: var(--text-h);
}

.save-btn:disabled,
.publish-btn:disabled,
.cancel-btn:disabled {
  opacity: 0.6;
  cursor: default;
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
  background: var(--bg);
}

@media (max-width: 768px) {
  .doc-page {
    padding: 16px;
  }
}
</style>
