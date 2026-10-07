# LLM Stats

A [Omarchy](https://omarchy.org/) / [Hyprland](https://hypr.land/) status bar plugin that shows real-time token generation speed from a running `llama-server` instance.

Displays combined prompt processing and decode throughput with emoji indicators, directly in your status bar. Click to see detailed stats including model name, uptime, token counts, and per-second speeds.

## Features

- **Real-time monitoring** — Polls the llama.cpp `/slots` endpoint and calculates speeds from token count deltas
- **Dual metrics** — Shows both prompt processing speed and decode speed
- **Emoji states** — 💀 offline, 🤖 idle, 🐌 slow, ⚡ fast, 🚀 insane
- **Theme-aware** — Colors change based on speed thresholds (green/yellow/red)
- **Detail panel** — Click for model name, uptime, and full token counts
- **Configurable** — Server URL, refresh interval, display options

## Install

```bash
omarchy plugin add https://github.com/flyingpizza/omarchy-llm-stats.git --enable
```

After installing, the plugin appears on the right side of your bar. Move it if needed:

```bash
# Center placement
omarchy bar move flyingpizza.llm-stats --section center --after omarchy.clock

# Left placement
omarchy bar move flyingpizza.llm-stats --section left --after omarchy.workspaces

# Right placement (default, next to agents)
omarchy bar move flyingpizza.llm-stats --section right --before omarchy.agents
```

## Requirements

- [Omarchy](https://omarchy.org/) Quattro with Quickshell
- A running `llama-server` instance (any llama.cpp build, no `--perf` flag needed)
- `python3` (standard library only)

## Configuration

Click the plugin in the bar to open settings:

| Setting | Default | Description |
|---------|---------|-------------|
| Server URL | `http://localhost:5800` | Base URL of the llama-server |
| Refresh interval | `2` seconds | How often to poll the server |
| Show prompt speed | `On` | Display prompt processing throughput |
| Show decode speed | `On` | Display token generation throughput |
| Compact display | `On` | Compact shows `99p 30d`, full shows `99p/s 30t/s` |

## Emoji States

| Speed | Emoji | Meaning |
|-------|-------|--------|
| Error | 💀 | Server offline |
| 0 t/s | 🤖 | Idle |
| 1-10 t/s | 🐌 | Slow |
| 10-30 t/s | 🤖 | Normal |
| 30-50 t/s | ⚡ | Fast |
| >50 t/s | 🚀 | Insane |

## Display Format

### Bar (compact mode)
```
🚀 99p 30d
```

### Bar (full mode)
```
⚡ 99.0p/s 30.0t/s
```

### Click panel
```
🤖 LLM Stats
─────────────────
Model:     Qwen_Qwen3.6-35B-A3B-Q4_K_M
Status:    ⚡ Active
Active Slots: 1/2
─────────────────
Prompt Processing
Tokens:    128,456
Speed:     99.4 t/s
─────────────────
Decoding
Tokens:    45,231
Speed:     30.2 t/s
```

## Color Behavior

- **Accent color** — Decode speed > 40 t/s (fast)
- **Muted color** — Decode speed 10–40 t/s (normal)
- **Urgent color** — Server unreachable or error

## How It Works

1. The plugin polls `GET http://<server>/slots` twice, 2 seconds apart
2. Token counts (`n_prompt_tokens_processed`, `n_decoded`) are extracted from each slot
3. Speeds are calculated from the delta between polls
4. Model.js formats this data for display with emoji states
5. The bar widget shows combined throughput with emoji

## Development

Run the collector directly to test:

```bash
python3 collect.py [--server-url URL] [--interval SECONDS]
```

## Uninstall

```bash
omarchy plugin remove flyingpizza.llm-stats
```

## License

MIT

## Author

flyingpizza
