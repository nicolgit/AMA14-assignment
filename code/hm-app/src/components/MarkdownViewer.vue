<script setup lang="ts">
import { computed } from 'vue'
import { marked } from 'marked'
import DOMPurify from 'dompurify'

const props = defineProps<{ source: string }>()

// marked renders the markdown to HTML; DOMPurify strips any unsafe markup
// (scripts, event handlers, etc.) since the content comes from blob storage.
const html = computed(() => {
  const raw = marked.parse(props.source ?? '', { async: false, gfm: true, breaks: false }) as string
  return DOMPurify.sanitize(raw)
})
</script>

<template>
  <!-- eslint-disable-next-line vue/no-v-html -->
  <div class="markdown-body" v-html="html"></div>
</template>

<style scoped>
.markdown-body {
  width: 100%;
  box-sizing: border-box;
  color: var(--text-h);
  font-size: 0.95rem;
  line-height: 1.65;
  word-wrap: break-word;
  text-align: left;
}

.markdown-body :deep(h1),
.markdown-body :deep(h2),
.markdown-body :deep(h3),
.markdown-body :deep(h4) {
  color: var(--text-h);
  line-height: 1.25;
  margin: 1.4em 0 0.6em;
  font-weight: 700;
}

.markdown-body :deep(h1) {
  font-size: 1.6rem;
  padding-bottom: 0.3em;
  border-bottom: 1px solid var(--border);
}

.markdown-body :deep(h2) {
  font-size: 1.3rem;
  padding-bottom: 0.3em;
  border-bottom: 1px solid var(--border);
}

.markdown-body :deep(h3) {
  font-size: 1.1rem;
}

.markdown-body :deep(h4) {
  font-size: 1rem;
}

.markdown-body :deep(p) {
  margin: 0 0 1em;
}

.markdown-body :deep(a) {
  color: var(--accent);
  text-decoration: none;
}

.markdown-body :deep(a:hover) {
  text-decoration: underline;
}

.markdown-body :deep(ul),
.markdown-body :deep(ol) {
  margin: 0 0 1em;
  padding-left: 1.6em;
}

.markdown-body :deep(li) {
  margin: 0.25em 0;
}

.markdown-body :deep(blockquote) {
  margin: 0 0 1em;
  padding: 0.4em 1em;
  color: var(--text);
  border-left: 4px solid var(--accent-border);
  background: var(--accent-bg);
  border-radius: 0 8px 8px 0;
}

.markdown-body :deep(hr) {
  border: none;
  border-top: 1px solid var(--border);
  margin: 1.6em 0;
}

.markdown-body :deep(code) {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.85em;
  padding: 0.15em 0.4em;
  border-radius: 6px;
  background: var(--social-bg);
}

.markdown-body :deep(pre) {
  margin: 0 0 1em;
  padding: 14px 16px;
  border-radius: 10px;
  background: var(--social-bg);
  border: 1px solid var(--border);
  overflow-x: auto;
}

.markdown-body :deep(pre code) {
  padding: 0;
  background: transparent;
  font-size: 0.85rem;
  line-height: 1.5;
}

.markdown-body :deep(table) {
  border-collapse: collapse;
  width: 100%;
  margin: 0 0 1.2em;
  font-size: 0.88rem;
  display: block;
  overflow-x: auto;
}

.markdown-body :deep(th),
.markdown-body :deep(td) {
  border: 1px solid var(--border);
  padding: 8px 12px;
  text-align: left;
}

.markdown-body :deep(th) {
  background: var(--accent-bg);
  color: var(--text-h);
  font-weight: 700;
}

.markdown-body :deep(tr:nth-child(even) td) {
  background: var(--social-bg);
}

.markdown-body :deep(img) {
  max-width: 100%;
  height: auto;
}

.markdown-body :deep(strong) {
  color: var(--text-h);
}
</style>
