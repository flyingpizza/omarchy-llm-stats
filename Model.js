function clamp(value, lo, hi) {
  var n = Number(value)
  if (!isFinite(n)) return lo
  return Math.max(lo, Math.min(hi, n))
}

function isOn(value, fallback) {
  if (value === undefined || value === null || value === "") return !!fallback
  if (typeof value === "boolean") return value
  var s = String(value).replace(/^\s+|\s+$/g, "").toLowerCase()
  if (s === "on" || s === "true" || s === "1" || s === "yes") return true
  if (s === "off" || s === "false" || s === "0" || s === "no") return false
  return !!fallback
}

function fileUrlToPath(url) {
  var s = String(url || "")
  if (s.indexOf("file://") === 0) s = s.substring(7)
  try {
    return decodeURIComponent(s)
  } catch (e) {
    return s
  }
}

function emptySnapshot() {
  return {
    ok: false,
    ts: 0,
    uptime_ms: null,
    model: null,
    prompt: { n_tokens: null, per_second: null },
    decode: { n_tokens: null, per_second: null },
    active_slots: 0,
    total_slots: 0,
    error: null
  }
}

function parseSnapshot(raw) {
  var text = String(raw || "").replace(/^\s+|\s+$/g, "")
  if (!text) return null
  try {
    var data = JSON.parse(text)
    if (!data || typeof data !== "object") return null

    var snapshot = emptySnapshot()
    snapshot.ok = true
    snapshot.ts = Date.now()

    // Detect format: new /slots-based format has prompt_speed/decode_speed
    // Old /stats format has time_ms/prompt_per_second/decoded_per_second
    var hasNewFormat = data.prompt_speed !== undefined || data.decode_speed !== undefined

    if (hasNewFormat) {
      // New /slots-based format (polls twice to calculate speed)
      if (data.prompt_speed !== undefined) {
        snapshot.prompt.per_second = Number(data.prompt_speed)
      }
      if (data.decode_speed !== undefined) {
        snapshot.decode.per_second = Number(data.decode_speed)
      }
      if (data.prompt_tokens !== undefined) {
        snapshot.prompt.n_tokens = Number(data.prompt_tokens)
      }
      if (data.decode_tokens !== undefined) {
        snapshot.decode.n_tokens = Number(data.decode_tokens)
      }
      if (data.active_slots !== undefined) {
        snapshot.active_slots = Number(data.active_slots)
      }
      if (data.total_slots !== undefined) {
        snapshot.total_slots = Number(data.total_slots)
      }
      if (data.status === "ok" && snapshot.active_slots === 0) {
        // If no active slots but we got data, it's idle (not an error)
      }
    } else {
      // Old /stats endpoint format (llama.cpp with --perf)
      if (data.time_ms !== undefined) {
        snapshot.uptime_ms = Number(data.time_ms)
      }
      if (data.model && String(data.model)) {
        snapshot.model = String(data.model)
      } else if (data.model_path) {
        snapshot.model = String(data.model_path)
      }

      if (data.prompt_per_second !== undefined) {
        snapshot.prompt.per_second = Number(data.prompt_per_second)
      }
      if (data.prompt_n_tokens !== undefined) {
        snapshot.prompt.n_tokens = Number(data.prompt_n_tokens)
      }
      if (data.decoded_per_second !== undefined) {
        snapshot.decode.per_second = Number(data.decoded_per_second)
      }
      if (data.decoded_n_tokens !== undefined) {
        snapshot.decode.n_tokens = Number(data.decoded_n_tokens)
      }
    }

    // Handle error case
    if (data.error || data.status === "error") {
      snapshot.ok = false
      snapshot.error = String(data.error || data.message || "Unknown error")
    }

    return snapshot
  } catch (e) {
    var err = emptySnapshot()
    err.ok = false
    err.error = "Parse error: " + String(e.message || e)
    return err
  }
}

function getEmoji(snapshot) {
  // Error state
  if (!snapshot.ok || snapshot.error) {
    return { emoji: "💀", label: "offline" }
  }

  var hasPrompt = snapshot.prompt.per_second !== null && Number(snapshot.prompt.per_second || 0) > 0
  var hasDecode = snapshot.decode.per_second !== null && Number(snapshot.decode.per_second || 0) > 0

  // No active generation
  if (!hasPrompt && !hasDecode) {
    return { emoji: "🤖", label: "idle" }
  }

  // Decode speed determines emoji
  var speed = snapshot.decode.per_second !== null ? snapshot.decode.per_second : 0

  if (speed > 50) {
    return { emoji: "🚀", label: "insane" }
  } else if (speed > 30) {
    return { emoji: "⚡", label: "fast" }
  } else if (speed > 10) {
    return { emoji: "🤖", label: "normal" }
  } else if (speed > 0) {
    return { emoji: "🐌", label: "slow" }
  }

  return { emoji: "🤖", label: "idle" }
}

function formatSpeed(perSecond, emptyText) {
  if (perSecond === undefined || perSecond === null || !isFinite(Number(perSecond)))
    return emptyText || "—"
  var n = Number(perSecond)
  return n.toFixed(1)
}

function formatTokenCount(nTokens, emptyText) {
  if (nTokens === undefined || nTokens === null || !isFinite(Number(nTokens)))
    return emptyText || "—"
  return Math.round(Number(nTokens)).toLocaleString()
}

function formatUptime(ms, emptyText) {
  if (ms === undefined || ms === null || !isFinite(Number(ms)))
    return emptyText || "—"
  var totalSec = Math.floor(Number(ms) / 1000)
  var hours = Math.floor(totalSec / 3600)
  var minutes = Math.floor((totalSec % 3600) / 60)
  var seconds = totalSec % 60
  if (hours > 0) {
    return hours + "h " + (minutes < 10 ? "0" : "") + minutes + "m"
  }
  return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
}

function formatCompactBar(snapshot, settings) {
  // Bar shows a single t/s number only (decode preferred, prompt as fallback).
  // Full detail (model, tokens, both speeds) goes to the mouseover tooltip.
  var status = getEmoji(snapshot)

  var ps = Number(snapshot.decode && snapshot.decode.per_second || 0)
  if (ps <= 0) ps = Number(snapshot.prompt && snapshot.prompt.per_second || 0)

  if (ps > 0) {
    var text = status.emoji + " " + Math.round(ps) + "t/s"
    return { text: text, tooltip: buildTooltip(snapshot, settings), value: text, detail: status.label, emoji: status.emoji }
  }

  if (!snapshot.ok) {
    return { text: status.emoji, tooltip: "LLM server offline", value: status.emoji, detail: "offline", emoji: status.emoji }
  }

  return { text: status.emoji, tooltip: "No active generation", value: status.emoji, detail: "idle", emoji: status.emoji }
}

function buildTooltip(snapshot, settings) {
  var lines = []
  lines.push("Model: " + (snapshot.model || "Unknown"))
  lines.push("Uptime: " + formatUptime(snapshot.uptime_ms, "—"))
  if (snapshot.active_slots !== undefined) {
    lines.push("Active slots: " + snapshot.active_slots + "/" + snapshot.total_slots)
  }

  if (snapshot.prompt.per_second !== null) {
    lines.push("Prompt: " + formatTokenCount(snapshot.prompt.n_tokens) + " tokens @ " + formatSpeed(snapshot.prompt.per_second, "—") + " t/s")
  }
  if (snapshot.decode.per_second !== null) {
    lines.push("Decode: " + formatTokenCount(snapshot.decode.n_tokens) + " tokens @ " + formatSpeed(snapshot.decode.per_second, "—") + " t/s")
  }

  return lines.join("\n")
}

function panelData(snapshot, settings) {
  var showPrompt = isOn(settings && settings.showPrompt, true)
  var showDecode = isOn(settings && settings.showDecode, true)
  var rows = []

  var emojiStatus = getEmoji(snapshot)
  rows.push({ label: "Model", value: snapshot.model || "Unknown" })
  rows.push({ label: "Status", value: snapshot.ok ? "Active" : "Offline", emoji: emojiStatus.emoji })
  if (snapshot.uptime_ms !== null) {
    rows.push({ label: "Uptime", value: formatUptime(snapshot.uptime_ms, "—") })
  }
  if (snapshot.active_slots !== undefined) {
    rows.push({ label: "Active Slots", value: snapshot.active_slots + "/" + snapshot.total_slots })
  }

  if (showPrompt) {
    rows.push({ label: "Prompt Tokens", value: formatTokenCount(snapshot.prompt.n_tokens) })
    rows.push({ label: "Prompt Speed", value: formatSpeed(snapshot.prompt.per_second, "—") + " t/s" })
  }

  if (showDecode) {
    rows.push({ label: "Decode Tokens", value: formatTokenCount(snapshot.decode.n_tokens) })
    rows.push({ label: "Decode Speed", value: formatSpeed(snapshot.decode.per_second, "—") + " t/s" })
  }

  return rows
}

if (typeof module !== "undefined") {
  module.exports = {
    clamp: clamp,
    isOn: isOn,
    fileUrlToPath: fileUrlToPath,
    emptySnapshot: emptySnapshot,
    parseSnapshot: parseSnapshot,
    formatSpeed: formatSpeed,
    formatTokenCount: formatTokenCount,
    formatUptime: formatUptime,
    formatCompactBar: formatCompactBar,
    buildTooltip: buildTooltip,
    panelData: panelData
  }
}
