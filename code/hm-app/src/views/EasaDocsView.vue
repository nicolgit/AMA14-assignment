<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount, nextTick, watch } from 'vue'
import { useRouter } from 'vue-router'
import PageHeader from '../components/PageHeader.vue'
import MarkdownViewer from '../components/MarkdownViewer.vue'
import { API_BASE_URL } from '../config'

const router = useRouter()

interface KbDocument {
  document_id: string
  title: string
  type: string | null
  revision: string | null
  date: string | null
  storage_uri: string | null
  status: string | null
}

const documents = ref<KbDocument[]>([])
const loading = ref(false)
const error = ref('')

const searchQuery = ref('')

const pageSize = 10
const currentPage = ref(1)

// View toggles between the document list and the Engineering Copilot chat.
type ViewMode = 'list' | 'chat'
const mode = ref<ViewMode>('list')

interface ChatReference {
  source: string
  path?: string | null
  snippet?: string | null
}

interface ChatTurn {
  role: 'user' | 'assistant'
  content: string
  references?: ChatReference[]
  taskCardMarkdown?: string | null
  taskCardTitle?: string | null
}

const chatTurns = ref<ChatTurn[]>([])
const chatLoading = ref(false)
const chatError = ref('')
const chatLog = ref<HTMLElement | null>(null)

type VoiceState = 'idle' | 'starting' | 'recording' | 'transcribing'
const voiceState = ref<VoiceState>('idle')
const voiceError = ref('')
const voiceStatus = ref('')

let microphoneStream: MediaStream | null = null
let audioContext: AudioContext | null = null
let audioSource: MediaStreamAudioSourceNode | null = null
let audioProcessor: ScriptProcessorNode | null = null
let silentOutput: GainNode | null = null
let audioChunks: Float32Array[] = []
let recordingSampleRate = 48_000
let recordingTimer: ReturnType<typeof setTimeout> | null = null

// Index of the task-card turn currently being promoted into a document, so the
// button can show a busy state and stay disabled during the request.
const creatingCardIndex = ref<number | null>(null)

// Auto-scroll the chat log to the bottom whenever a turn is added.
watch(
  () => [chatTurns.value.length, chatLoading.value],
  async () => {
    await nextTick()
    chatLog.value?.scrollTo({ top: chatLog.value.scrollHeight })
  },
)

const filteredDocuments = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return documents.value
  return documents.value.filter((d) =>
    [d.document_id, d.title, d.type, d.revision, d.storage_uri]
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

function toggleMode() {
  mode.value = mode.value === 'list' ? 'chat' : 'list'
}

// Pressing Enter (or the primary button) starts/continues the chat.
function onSubmit() {
  const text = searchQuery.value.trim()
  if (!text || chatLoading.value) return
  mode.value = 'chat'
  sendChat(text)
}

async function sendChat(text: string) {
  chatError.value = ''
  chatTurns.value.push({ role: 'user', content: text })
  searchQuery.value = ''
  chatLoading.value = true
  try {
    const payload = {
      messages: chatTurns.value.map((t) => ({ role: t.role, content: t.content })),
    }
    const res = await fetch(`${API_BASE_URL}/v1/engineering/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    })
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
    const data = await res.json()
    chatTurns.value.push({
      role: 'assistant',
      content: data.reply ?? '',
      references: data.references ?? [],
      taskCardMarkdown: data.task_card_draft?.markdown ?? null,
      taskCardTitle: data.task_card_draft?.title ?? null,
    })
  } catch (err) {
    chatError.value = err instanceof Error ? err.message : String(err)
  } finally {
    chatLoading.value = false
  }
}

function encodeWav(chunks: Float32Array[], sampleRate: number): Blob {
  const sampleCount = chunks.reduce((total, chunk) => total + chunk.length, 0)
  const buffer = new ArrayBuffer(44 + sampleCount * 2)
  const view = new DataView(buffer)

  const writeText = (offset: number, value: string) => {
    for (let index = 0; index < value.length; index++) {
      view.setUint8(offset + index, value.charCodeAt(index))
    }
  }

  writeText(0, 'RIFF')
  view.setUint32(4, 36 + sampleCount * 2, true)
  writeText(8, 'WAVE')
  writeText(12, 'fmt ')
  view.setUint32(16, 16, true)
  view.setUint16(20, 1, true)
  view.setUint16(22, 1, true)
  view.setUint32(24, sampleRate, true)
  view.setUint32(28, sampleRate * 2, true)
  view.setUint16(32, 2, true)
  view.setUint16(34, 16, true)
  writeText(36, 'data')
  view.setUint32(40, sampleCount * 2, true)

  let offset = 44
  for (const chunk of chunks) {
    for (const sample of chunk) {
      const normalized = Math.max(-1, Math.min(1, sample))
      view.setInt16(offset, normalized < 0 ? normalized * 0x8000 : normalized * 0x7fff, true)
      offset += 2
    }
  }

  return new Blob([buffer], { type: 'audio/wav' })
}

function releaseMicrophone() {
  if (recordingTimer) clearTimeout(recordingTimer)
  recordingTimer = null
  audioProcessor?.disconnect()
  audioSource?.disconnect()
  silentOutput?.disconnect()
  microphoneStream?.getTracks().forEach((track) => track.stop())
  if (audioContext && audioContext.state !== 'closed') void audioContext.close()
  microphoneStream = null
  audioContext = null
  audioSource = null
  audioProcessor = null
  silentOutput = null
}

async function startRecording() {
  voiceError.value = ''
  voiceStatus.value = ''
  if (!navigator.mediaDevices?.getUserMedia) {
    voiceError.value = 'Voice input is not supported by this browser.'
    return
  }

  voiceState.value = 'starting'
  try {
    microphoneStream = await navigator.mediaDevices.getUserMedia({
      audio: { echoCancellation: true, noiseSuppression: true },
    })
    audioContext = new AudioContext()
    if (audioContext.state === 'suspended') await audioContext.resume()
    recordingSampleRate = audioContext.sampleRate
    audioChunks = []
    audioSource = audioContext.createMediaStreamSource(microphoneStream)
    audioProcessor = audioContext.createScriptProcessor(4096, 1, 1)
    silentOutput = audioContext.createGain()
    silentOutput.gain.value = 0
    audioProcessor.onaudioprocess = (event) => {
      audioChunks.push(new Float32Array(event.inputBuffer.getChannelData(0)))
    }
    audioSource.connect(audioProcessor)
    audioProcessor.connect(silentOutput)
    silentOutput.connect(audioContext.destination)
    voiceState.value = 'recording'
    voiceStatus.value = 'Listening… Click the microphone to stop.'
    recordingTimer = setTimeout(() => void stopAndTranscribe(), 30_000)
  } catch (err) {
    releaseMicrophone()
    voiceState.value = 'idle'
    voiceError.value =
      err instanceof Error ? err.message : 'Microphone access was not granted.'
  }
}

async function stopAndTranscribe() {
  if (voiceState.value !== 'recording') return
  voiceState.value = 'transcribing'
  voiceStatus.value = 'Transcribing…'

  const chunks = audioChunks
  const sampleRate = recordingSampleRate
  if (audioProcessor) audioProcessor.onaudioprocess = null
  releaseMicrophone()

  if (!chunks.length) {
    voiceState.value = 'idle'
    voiceStatus.value = ''
    voiceError.value = 'No audio was recorded.'
    return
  }

  try {
    const form = new FormData()
    form.append('audio', encodeWav(chunks, sampleRate), 'voice-input.wav')
    const res = await fetch(`${API_BASE_URL}/v1/speech/transcribe`, {
      method: 'POST',
      body: form,
    })
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

    const data = await res.json()
    const transcript = String(data.text ?? '').trim()
    if (!transcript) throw new Error('No speech could be recognized.')
    searchQuery.value = [searchQuery.value.trim(), transcript].filter(Boolean).join(' ')
    voiceStatus.value = `Detected language: ${data.language ?? 'unknown'}. Review the text, then press Send.`
  } catch (err) {
    voiceStatus.value = ''
    voiceError.value = err instanceof Error ? err.message : String(err)
  } finally {
    voiceState.value = 'idle'
  }
}

function toggleMic() {
  if (voiceState.value === 'idle') void startRecording()
  else if (voiceState.value === 'recording') void stopAndTranscribe()
}

// Promote a drafted task card into a real (draft-status) document: create the
// .md file + a `document` row server-side, then open the new card's detail view.
async function workOnTaskCard(turn: ChatTurn, index: number) {
  if (!turn.taskCardMarkdown || creatingCardIndex.value !== null) return
  if (!window.confirm('Create a draft task card document and open it for editing?')) {
    return
  }

  chatError.value = ''
  creatingCardIndex.value = index
  try {
    const res = await fetch(`${API_BASE_URL}/v1/engineering/task-card`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title: turn.taskCardTitle || 'Draft task card',
        markdown: turn.taskCardMarkdown,
      }),
    })
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
    const data = await res.json()
    await router.push({
      name: 'easa-doc-detail',
      params: { docid: data.document_id },
    })
  } catch (err) {
    chatError.value = err instanceof Error ? err.message : String(err)
  } finally {
    creatingCardIndex.value = null
  }
}

async function loadDocuments() {
  loading.value = true
  error.value = ''
  try {
    const res = await fetch(`${API_BASE_URL}/v1/doc`)
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
    documents.value = await res.json()
    currentPage.value = 1
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
}

function docTypeClass(type: string | null): string {
  const key = (type ?? '').replace(/\s+/g, '').toLowerCase()
  return `doc-type doc-type--${key}`
}

function statusClass(status: string | null): string {
  const key = (status ?? '').trim().toLowerCase()
  return `status-pill status-pill--${key}`
}

// Map a source file name (as returned by the RAG index) to its document title,
// using the document list already loaded for the table.
const docTitleByFile = computed(() => {
  const map: Record<string, string> = {}
  for (const d of documents.value) {
    if (!d.storage_uri || !d.title) continue
    const file = d.storage_uri.split('/').pop()
    if (file) map[file] = d.title
  }
  return map
})

// Map a source file name to its document_id, so chat sources can link to the
// document detail view.
const docIdByFile = computed(() => {
  const map: Record<string, string> = {}
  for (const d of documents.value) {
    if (!d.storage_uri) continue
    const file = d.storage_uri.split('/').pop()
    if (file) map[file] = d.document_id
  }
  return map
})

function titleForSource(source: string | null | undefined): string {
  if (!source) return ''
  return docTitleByFile.value[source] ?? ''
}

function docIdForSource(source: string | null | undefined): string {
  if (!source) return ''
  return docIdByFile.value[source] ?? ''
}

onMounted(loadDocuments)
onBeforeUnmount(releaseMicrophone)
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
          :placeholder="
            mode === 'chat'
              ? 'Ask the Engineering Copilot…'
              : 'e.g. borescope inspection procedure for HP compressor'
          "
          @keyup.enter="onSubmit"
        />
        <button
          :class="['mic-btn', { 'mic-btn--recording': voiceState === 'recording' }]"
          type="button"
          :title="voiceState === 'recording' ? 'Stop recording' : 'Start voice input'"
          :aria-label="voiceState === 'recording' ? 'Stop recording' : 'Start voice input'"
          :aria-pressed="voiceState === 'recording'"
          :disabled="voiceState === 'starting' || voiceState === 'transcribing'"
          @click="toggleMic"
        >
          {{ voiceState === 'recording' ? '■' : voiceState === 'transcribing' ? '…' : '🎙️' }}
        </button>
        <button class="toggle-btn" type="button" @click="toggleMode">
          {{ mode === 'list' ? '💬 Chat' : '📋 Documents' }}
        </button>
        <button class="search-btn" type="button" @click="onSubmit">
          {{ mode === 'chat' ? 'Send' : 'Ask AI' }}
        </button>
      </div>
      <p v-if="voiceStatus" class="voice-state" aria-live="polite">{{ voiceStatus }}</p>
      <p v-if="voiceError" class="voice-state state--error" role="alert">{{ voiceError }}</p>
    </section>

    <section v-if="mode === 'list'" class="content">
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
              <th>Revision</th>
              <th>Date</th>
              <th>Storage URI</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="doc in pagedDocuments" :key="doc.document_id">
              <td class="doc-id">{{ doc.document_id }}</td>
              <td>{{ doc.title }}</td>
              <td><span :class="docTypeClass(doc.type)">{{ doc.type }}</span></td>
              <td>{{ doc.revision }}</td>
              <td>{{ doc.date }}</td>
              <td class="doc-source">
                <router-link
                  class="doc-uri-link"
                  :to="{ name: 'easa-doc-detail', params: { docid: doc.document_id } }"
                >
                  {{ doc.storage_uri }}
                </router-link>
              </td>
              <td>
                <span :class="statusClass(doc.status)">
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

    <section v-else class="chat">
      <div class="content-head">
        <h3 class="content-title">
          <span class="ai-badge">AI</span> Engineering Copilot
        </h3>
        <button class="link-btn" type="button" @click="mode = 'list'">
          ← Back to documents
        </button>
      </div>

      <div ref="chatLog" class="chat-log">
        <p v-if="chatTurns.length === 0 && !chatLoading" class="chat-empty">
          Ask about a procedure, retrieve a historical task card, or request a
          pre-filled draft task card. The copilot cites its sources and proposes
          drafts for a human engineer to validate.
        </p>

        <div
          v-for="(turn, i) in chatTurns"
          :key="i"
          :class="['chat-msg', turn.role === 'user' ? 'chat-msg--user' : 'chat-msg--ai']"
        >
          <div class="chat-bubble">
            <MarkdownViewer
              v-if="turn.role === 'assistant'"
              :source="turn.content"
              class="chat-text"
            />
            <p v-else class="chat-text">{{ turn.content }}</p>

            <div v-if="turn.taskCardMarkdown" class="task-card">
              <div class="task-card-head">📝 Draft task card — pending review</div>
              <MarkdownViewer :source="turn.taskCardMarkdown" class="task-card-body" />
              <div class="task-card-actions">
                <button
                  class="task-card-btn"
                  type="button"
                  :disabled="creatingCardIndex !== null"
                  @click="workOnTaskCard(turn, i)"
                >
                  {{ creatingCardIndex === i ? 'Creating…' : '🛠️ Work on this task card' }}
                </button>
              </div>
            </div>

            <div v-if="turn.references && turn.references.length" class="refs">
              <span class="refs-title">Sources</span>
              <ul class="refs-list">
                <li v-for="(r, ri) in turn.references" :key="ri">
                  <router-link
                    v-if="docIdForSource(r.source)"
                    class="ref-file ref-file--link"
                    :to="{ name: 'easa-doc-detail', params: { docid: docIdForSource(r.source) } }"
                  >
                    {{ r.source }}
                  </router-link>
                  <span v-else class="ref-file">{{ r.source }}</span>
                  <span v-if="titleForSource(r.source)" class="ref-doc-title">
                    — {{ titleForSource(r.source) }}
                  </span>
                </li>
              </ul>
            </div>
          </div>
        </div>

        <div v-if="chatLoading" class="chat-msg chat-msg--ai">
          <div class="chat-bubble chat-bubble--loading">Thinking…</div>
        </div>

        <p v-if="chatError" class="state state--error">⚠️ {{ chatError }}</p>
      </div>
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

.mic-btn:disabled {
  cursor: wait;
  opacity: 0.65;
}

.mic-btn--recording {
  color: #fff;
  border-color: #c62f36;
  background: #e5484d;
  animation: recording-pulse 1.4s ease-in-out infinite;
}

.voice-state {
  min-height: 20px;
  margin: 8px 16px 0;
  color: var(--text);
  font-size: 0.82rem;
}

@keyframes recording-pulse {
  50% {
    box-shadow: 0 0 0 5px rgba(229, 72, 77, 0.18);
  }
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

.doc-uri-link {
  color: var(--accent);
  text-decoration: none;
  word-break: break-all;
}

.doc-uri-link:hover {
  text-decoration: underline;
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

.status-pill--published {
  color: #1a7f37;
  background: rgba(26, 127, 55, 0.12);
}

.status-pill--draft {
  color: #b57400;
  background: rgba(245, 166, 35, 0.12);
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

/* Toggle button (chat / documents) */
.toggle-btn {
  border: 1px solid var(--accent-border);
  background: var(--accent-bg);
  color: var(--accent);
  border-radius: 999px;
  padding: 9px 16px;
  font-weight: 700;
  cursor: pointer;
  flex-shrink: 0;
  white-space: nowrap;
}

.toggle-btn:hover {
  filter: brightness(1.03);
}

/* Chat */
.chat {
  width: 100%;
}

.link-btn {
  border: none;
  background: transparent;
  color: var(--accent);
  font-weight: 600;
  font-size: 0.85rem;
  cursor: pointer;
  padding: 0;
}

.link-btn:hover {
  text-decoration: underline;
}

.chat-log {
  display: flex;
  flex-direction: column;
  gap: 14px;
  max-height: 60vh;
  overflow-y: auto;
  padding: 4px;
}

.chat-empty {
  font-size: 0.92rem;
  color: var(--text);
  max-width: 640px;
  line-height: 1.5;
}

.chat-msg {
  display: flex;
}

.chat-msg--user {
  justify-content: flex-end;
}

.chat-msg--ai {
  justify-content: flex-start;
}

.chat-bubble {
  max-width: 80%;
  padding: 12px 16px;
  border-radius: 14px;
  border: 1px solid var(--border);
  background: var(--bg);
}

.chat-msg--user .chat-bubble {
  background: var(--accent);
  border-color: var(--accent-border);
  color: #fff;
}

.chat-bubble--loading {
  color: var(--text);
  font-style: italic;
}

.chat-text {
  margin: 0;
  font-size: 0.92rem;
  line-height: 1.5;
  white-space: pre-wrap;
  text-align: left;
}

.task-card {
  margin-top: 12px;
  border: 1px solid var(--accent-border);
  border-radius: 10px;
  overflow: hidden;
}

.task-card-head {
  background: var(--accent-bg);
  color: var(--accent);
  font-weight: 700;
  font-size: 0.8rem;
  padding: 8px 12px;
}

.task-card-body {
  padding: 12px;
  font-size: 0.82rem;
  background: var(--social-bg);
}

.task-card-actions {
  display: flex;
  justify-content: flex-end;
  padding: 10px 12px;
  border-top: 1px solid var(--accent-border);
  background: var(--accent-bg);
}

.task-card-btn {
  border: none;
  border-radius: 8px;
  padding: 8px 14px;
  font-size: 0.82rem;
  font-weight: 700;
  cursor: pointer;
  color: #fff;
  background: var(--accent);
}

.task-card-btn:hover:not(:disabled) {
  filter: brightness(1.08);
}

.task-card-btn:disabled {
  opacity: 0.6;
  cursor: default;
}

.refs {
  margin-top: 12px;
  padding-top: 10px;
  border-top: 1px dashed var(--border);
}

.refs-title {
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.6px;
  color: var(--text);
}

.refs-list {
  margin: 6px 0 0;
  padding-left: 18px;
  font-size: 0.82rem;
  color: var(--text-h);
}

.ref-file {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
}

.ref-file--link {
  color: var(--accent);
  text-decoration: none;
}

.ref-file--link:hover {
  text-decoration: underline;
}

.ref-doc-title {
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
