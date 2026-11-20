// DeepWorks serves its own models from DeepFoundry, an OpenAI-compatible
// gateway at tokenhub.deepexios.cn, and exposes nothing about them to the
// outside: its HTTP API is a private control plane behind a bearer token.
// What it does leave on disk is its engine's runtime folder — dth.json with
// the model list, dth-auth.json with the key that signs a request — so that
// is what this plugin reads.
//
// The key belongs to a DeepWorks identity rather than to one request, but a
// re-sign-in or another account mints a different one. Reading it per
// request, in chat.headers, means a key minted since the last request is the
// one that goes out: no renewal, no restart.

import { readFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

const TAIL = "Library/Application Support/com.deepexi.deepworks/deepworks-engine-data/config/opencode/deepworks-runtime"

const FALLBACK_BASE = "https://tokenhub.deepexios.cn/gateway/api/v1"

// The entries DeepWorks lists beside its chat models: transcription, document
// parsing and two web tools answer their own routes, not a conversation.
const NOT_CHAT = new Set(["Deepexi-ASR-1.0", "Deepexi-Xparse", "deepseek-web-fetch", "deepseek-web-search"])

function runtimeDir() {
  const fromEnv = (process.env.DEEPWORKS_RUNTIME_DIR || "").trim()
  if (fromEnv) return fromEnv
  if (process.platform === "darwin") return join(homedir(), TAIL)
  if (process.platform === "win32") {
    const appdata = process.env.APPDATA || join(homedir(), "AppData", "Roaming")
    return join(appdata, "com.deepexi.deepworks", "deepworks-engine-data", "config", "opencode", "deepworks-runtime")
  }
  const cfg = process.env.XDG_CONFIG_HOME || join(homedir(), ".config")
  return join(cfg, "com.deepexi.deepworks", "deepworks-engine-data", "config", "opencode", "deepworks-runtime")
}

function readJSON(name) {
  try {
    return JSON.parse(readFileSync(join(runtimeDir(), name), "utf8"))
  } catch {
    return null
  }
}

function key() {
  const a = readJSON("dth-auth.json")
  return typeof a?.dth?.key === "string" ? a.dth.key.trim() : ""
}

// The catalog as OpenCode's config wants it: one entry per model, with the
// limits and modalities DeepWorks itself wrote down.
function catalog() {
  const c = readJSON("dth.json")
  const dth = c?.provider?.dth
  if (!dth?.models) return { base: FALLBACK_BASE, models: {} }
  const base = typeof dth.options?.baseURL === "string" && dth.options.baseURL ? dth.options.baseURL : FALLBACK_BASE
  const models = {}
  for (const [id, m] of Object.entries(dth.models)) {
    const mid = typeof m?.id === "string" && m.id ? m.id : id
    if (NOT_CHAT.has(mid)) continue
    const inputs = Array.isArray(m?.modalities?.input) ? m.modalities.input : ["text"]
    const outputs = Array.isArray(m?.modalities?.output) ? m.modalities.output : ["text"]
    const efforts = m?.options?.__deepworksDthAttributes?.reasoningEfforts
    const entry = {
      id: mid,
      name: typeof m?.name === "string" && m.name ? m.name : mid,
      attachment: inputs.includes("image"),
      modalities: { input: inputs, output: outputs },
      tool_call: true,
    }
    if (typeof m?.reasoning === "boolean") entry.reasoning = m.reasoning
    if (Array.isArray(efforts) && efforts.length) {
      entry.variants = Object.fromEntries(efforts.map((e) => [e, { reasoningEffort: e }]))
    }
    if (m?.limit?.context || m?.limit?.output) {
      entry.limit = {}
      if (m.limit.context) entry.limit.context = m.limit.context
      if (m.limit.output) entry.limit.output = m.limit.output
    }
    models[mid] = entry
  }
  return { base, models }
}

export default {
  id: "deepworks",
  server: async () => ({
    // The provider is declared here rather than through a sign-in: there is
    // nothing to sign in to, only files to read.
    config(config) {
      const { base, models } = catalog()
      if (!Object.keys(models).length) return
      config.provider ??= {}
      config.provider.deepworks = {
        name: "DeepWorks",
        npm: "@ai-sdk/openai-compatible",
        options: { baseURL: base, apiKey: key() || "deepworks" },
        models,
      }
    },

    // One account, the plugin's own: no sign-in, no account list. The
    // loader is where magpie learns where to send the requests at all; the
    // key it gives is the one on disk now, and chat.headers below keeps it
    // current for every request after this.
    auth: {
      provider: "deepworks",
      single: true,
      methods: [],
      loader: async () => ({ baseURL: catalog().base, apiKey: key() || "deepworks" }),
    },

    // Every request, the key on disk now.
    "chat.headers": async (ctx, out) => {
      const provider = ctx?.model?.providerID
      if (provider !== "deepworks") return
      const k = key()
      if (k) out.headers.authorization = `Bearer ${k}`
    },
  }),
}
