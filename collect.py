#!/usr/bin/env python3
"""
Collects token generation statistics from a llama.cpp server using the /slots endpoint.

Polls /slots twice (1 second apart) to calculate prompt and decode token speeds
from the delta in token counts. Outputs JSON to stdout for the Quickshell bar widget.

Usage: python3 collect.py [--server-url URL] [--interval SECONDS]
Defaults to http://localhost:5802 with 2 second polling
"""

import json
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import urllib.error
from datetime import datetime, timezone


def fetch_slots(server_url: str) -> list:
    """Fetch /slots from the llama.cpp server. Returns list of slot dicts."""
    slots_url = f"{server_url}/slots"
    req = urllib.request.Request(slots_url, method="GET")
    req.add_header("Accept", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=3) as resp:
            data = json.loads(resp.read().decode())
            if isinstance(data, list):
                return data
            elif isinstance(data, dict) and "slots" in data:
                return data["slots"]
            return []
    except urllib.error.URLError as e:
        return None  # Signal connection error
    except json.JSONDecodeError:
        return []
    except Exception:
        return None


def fetch_props(server_url: str) -> dict:
    """Fetch /props from the llama.cpp server. Returns dict ({} on error)."""
    try:
        req = urllib.request.Request(f"{server_url}/props", method="GET")
        req.add_header("Accept", "application/json")
        with urllib.request.urlopen(req, timeout=3) as resp:
            data = json.loads(resp.read().decode())
            return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def model_name(props: dict):
    """Short display name from /props (basename of the model path, .gguf stripped)."""
    for key in ("model_alias", "model_path", "name"):
        value = props.get(key)
        if value and isinstance(value, str) and value.strip():
            name = value.rsplit("/", 1)[-1]
            if name.endswith(".gguf"):
                name = name[: -len(".gguf")]
            return name or None
    return None


_UPTIME_CACHE = {"cid": None, "started_ms": None}


def _parse_rfc3339_nano(raw: str):
    """Parse Docker's RFC3339Nano timestamp (e.g. 2026-10-07T15:40:12.123456789-04:00)."""
    m = re.match(
        r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:?\d{2})?",
        raw or "",
    )
    if not m:
        return None
    iso = m.group(1)
    frac = (m.group(2) or "")[:6]
    if frac:
        iso += "." + frac.ljust(6, "0")
    tz = m.group(3)
    if tz == "Z":
        iso += "+00:00"
    elif tz:
        iso += tz if ":" in tz else tz[:3] + ":" + tz[3:]
    try:
        return datetime.fromisoformat(iso)
    except ValueError:
        return None


def server_uptime_ms(port: int):
    """
    Uptime of the local Docker container publishing `port` (the llama-server host).
    Returns milliseconds since container start, or None if unavailable.
    """
    try:
        out = subprocess.run(
            ["docker", "ps", "--filter", f"publish={port}", "--format", "{{.ID}}"],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip()
        cid = out.splitlines()[0].strip() if out else None
        if not cid:
            return None
        # Re-inspect only when the container changes (model swap)
        if cid != _UPTIME_CACHE["cid"]:
            raw = subprocess.run(
                ["docker", "inspect", "--format", "{{.State.StartedAt}}", cid],
                capture_output=True, text=True, timeout=5,
            ).stdout.strip()
            started = _parse_rfc3339_nano(raw)
            if started is None:
                return None
            _UPTIME_CACHE["cid"] = cid
            _UPTIME_CACHE["started_ms"] = int(started.timestamp() * 1000)
        now_ms = int(time.time() * 1000)
        return max(0, now_ms - _UPTIME_CACHE["started_ms"])
    except Exception:
        return None


def calculate_speeds(slots: list) -> dict:
    """
    Calculate token speeds from slot data.
    Returns dict with prompt and decode token counts/speeds.
    """
    total_prompt_tokens = 0
    total_prompt_processed = 0
    total_decoded = 0

    for slot in slots:
        # Count prompt tokens from this slot
        total_prompt_tokens += slot.get("n_prompt_tokens", 0)
        total_prompt_processed += slot.get("n_prompt_tokens_processed", 0)

        # Get decoded tokens from next_token
        next_token = slot.get("next_token", [])
        if next_token and isinstance(next_token, list) and len(next_token) > 0:
            total_decoded += next_token[0].get("n_decoded", 0)

    return {
        "total_prompt_tokens": total_prompt_tokens,
        "total_prompt_processed": total_prompt_processed,
        "total_decoded": total_decoded
    }


def collect(server_url: str, interval: float = 2.0) -> dict:
    """
    Poll /slots twice with `interval` seconds between to calculate speeds.
    Returns stats dict with prompt/decode tokens and tokens/sec.
    """
    # First poll
    slots1 = fetch_slots(server_url)
    if slots1 is None:
        return {"error": "Cannot connect to server", "status": "error"}

    counts1 = calculate_speeds(slots1)

    # Wait
    time.sleep(interval)

    # Second poll
    slots2 = fetch_slots(server_url)
    if slots2 is None:
        return {"error": "Cannot connect to server", "status": "error"}

    counts2 = calculate_speeds(slots2)

    # Calculate deltas
    delta_prompt_processed = max(0, counts2["total_prompt_processed"] - counts1["total_prompt_processed"])
    delta_decoded = max(0, counts2["total_decoded"] - counts1["total_decoded"])

    # Calculate per-second speeds
    prompt_speed = delta_prompt_processed / interval
    decode_speed = delta_decoded / interval

    # Current totals from latest poll
    current_prompt = counts2["total_prompt_tokens"]
    current_decoded = counts2["total_decoded"]

    # Check if any slot is actively processing
    active_slots = sum(1 for s in slots2 if s.get("is_processing", False))

    result = {
        "prompt_tokens": current_prompt,
        "prompt_processed": counts2["total_prompt_processed"],
        "decode_tokens": current_decoded,
        "decode_processed": delta_decoded,
        "prompt_speed": round(prompt_speed, 1),
        "decode_speed": round(decode_speed, 1),
        "active_slots": active_slots,
        "total_slots": len(slots2),
        "status": "ok" if active_slots > 0 or current_decoded > 0 else "idle"
    }

    # Model name + server uptime (best-effort, never fail the snapshot)
    name = model_name(fetch_props(server_url))
    if name:
        result["model"] = name
    if "localhost" in server_url or "127.0.0.1" in server_url:
        try:
            port = urllib.parse.urlsplit(server_url).port
        except ValueError:
            port = None
        if port:
            up = server_uptime_ms(port)
            if up is not None:
                result["uptime_ms"] = up

    return result


def main():
    server_url = "http://localhost:5802"
    interval = 2.0

    # Parse command-line args
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] in ("--server-url", "-u") and i + 1 < len(args):
            server_url = args[i + 1]
            i += 2
        elif args[i] in ("--interval", "-i") and i + 1 < len(args):
            try:
                interval = float(args[i + 1])
            except ValueError:
                print(f"Invalid interval: {args[i + 1]}", file=sys.stderr)
                sys.exit(1)
            i += 2
        elif args[i] in ("--help", "-h"):
            print(f"Usage: {sys.argv[0]} [--server-url URL] [--interval SECONDS]")
            print(f"  Polls /slots twice to calculate token speeds")
            sys.exit(0)
        else:
            i += 1

    # Collect and output
    data = collect(server_url, interval)
    print(json.dumps(data))


if __name__ == "__main__":
    main()
