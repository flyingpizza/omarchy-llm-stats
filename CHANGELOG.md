# Changelog

## 2026.09.29
- **BREAKING**: Use `/slots` endpoint instead of `/stats` — no `--perf` flag required
- **NEW**: Emoji states based on decode speed (💀🤖🐌⚡🚀)
- **NEW**: Calculate speeds from token count deltas
- **NEW**: Active slots count in display
- **FIX**: Backward compatibility with old `/stats` format
- **FIX**: Proper idle detection (no more 0.0p 0.0d when idle)
- Updated README with emoji state table
- Updated manifest with correct author and description

## 2026.09.28
- Initial release
- Polls llama.cpp `/stats` endpoint
- Displays prompt & decode throughput
- Theme-aware colors
- Detail panel with model info
