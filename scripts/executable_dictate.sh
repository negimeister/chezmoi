#!/usr/bin/env bash
# dictate.sh - push-to-talk dictation for the desktop.
#
# Pipeline (modelled on the opencode-voice plugin, with a faster capture stage):
#   pw-record -> whisper-cli (local ggml model) -> LLM normalization -> paste
#
# Bind this to a hotkey. First press starts recording, second press stops,
# transcribes, sanitizes with the LLM, puts the text on the clipboard and
# pastes it into the focused window (Ctrl+V by default).
#
# Commands:
#   dictate.sh            toggle (default)
#   dictate.sh start|stop|cancel|status
#   dictate.sh last       re-emit the last transcription
#
# Config: ~/.config/dictate/config (plain shell, sourced), or env vars.
# Custom sanitizer prompt: ~/.config/dictate/prompt.md

set -uo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dictate"
[ -r "$CONFIG_DIR/config" ] && . "$CONFIG_DIR/config"

# ---- config -----------------------------------------------------------------
WHISPER_BIN="${DICTATE_WHISPER_BIN:-whisper-cli}"
WHISPER_MODEL="${DICTATE_MODEL:-$HOME/.local/share/whisper-cpp/ggml-large-v3-turbo-q5_0.bin}"
WHISPER_LANG="${DICTATE_LANG:-en}"
WHISPER_THREADS="${DICTATE_THREADS:-8}"
WHISPER_TIMEOUT="${DICTATE_WHISPER_TIMEOUT:-120}"

MIC="${DICTATE_MIC:-}"                              # source name; empty = system default
MAX_SECONDS="${DICTATE_MAX_SECONDS:-300}"           # hard cap on a recording
# Capture backend. pw-record is measurably the best here: it opens the stream in
# ~35ms and loses ~20ms on stop, where sox via the pulse compat layer needs
# ~220ms to open (clipping the first word) and, without PULSE_LATENCY_MSEC,
# throws away ~2s of tail on SIGINT.
RECORDER="${DICTATE_RECORDER:-auto}"                # auto | pw-record | parecord | sox
RECORD_LATENCY="${DICTATE_RECORD_LATENCY:-30ms}"    # pw-record stream latency
PULSE_LATENCY_MSEC="${DICTATE_PULSE_LATENCY_MSEC:-30}"  # sox/parecord fallbacks
SOX_BUFFER="${DICTATE_SOX_BUFFER:-1024}"
TAIL_MS="${DICTATE_TAIL_MS:-250}"                   # keep recording this long after "stop"
FILTER_HALLUCINATIONS="${DICTATE_FILTER_HALLUCINATIONS:-1}"
LOG_TRANSCRIPTS="${DICTATE_LOG_TRANSCRIPTS:-0}"     # 1 = write transcript text to the debug log

LLM_ENDPOINT="${DICTATE_LLM_ENDPOINT:-http://localhost:52625/v1}"
LLM_MODEL="${DICTATE_LLM_MODEL:-gemma4-it}"
LLM_API_KEY="${DICTATE_LLM_API_KEY:-}"
LLM_MAX_TOKENS="${DICTATE_LLM_MAX_TOKENS:-2048}"
LLM_TIMEOUT="${DICTATE_LLM_TIMEOUT:-60}"
LLM_RETRIES="${DICTATE_LLM_RETRIES:-2}"
LLM_EXTRA_JSON="${DICTATE_LLM_EXTRA_JSON:-}"        # e.g. '{"chat_template_kwargs":{"enable_thinking":false}}'
USE_LLM="${DICTATE_USE_LLM:-1}"

OUTPUT="${DICTATE_OUTPUT:-paste}"                   # paste | clip | type | stdout
NOTIFY="${DICTATE_NOTIFY:-1}"
PASTE_COMBO="${DICTATE_PASTE_COMBO:-auto}"          # auto | ctrl+v | ctrl+shift+v | shift+insert
CLEAR_MODIFIERS="${DICTATE_CLEAR_MODIFIERS:-1}"     # release hotkey modifiers before pasting
KEY_DELAY="${DICTATE_KEY_DELAY:-12}"                # ms between injected key events
PASTE_DELAY="${DICTATE_PASTE_DELAY:-0.15}"          # settle time after wl-copy, seconds
RESTORE_CLIPBOARD="${DICTATE_RESTORE_CLIPBOARD:-0}" # 1 = put the old clipboard back after pasting
TYPE_DELAY="${DICTATE_TYPE_DELAY:-4}"               # ms between keys (ydotool type mode)

RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/dictate"
mkdir -p "$RUN_DIR"
WAV="$RUN_DIR/rec.wav"
SOX_PID="$RUN_DIR/sox.pid"
BUSY="$RUN_DIR/busy"
LAST="$RUN_DIR/last.txt"
LOG="$RUN_DIR/dictate.log"

export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/.ydotool_socket}"

# ---- helpers ----------------------------------------------------------------
log() { printf '%s [%s] %s\n' "$(date +%H:%M:%S)" "${1}" "${2}" >>"$LOG"; }

notify() { # notify <summary> [body] [urgency]
  [ "$NOTIFY" = "1" ] || return 0
  command -v notify-send >/dev/null || return 0
  notify-send -a Dictate -i audio-input-microphone \
    -u "${3:-normal}" -t 2500 \
    -h string:x-canonical-private-synchronous:dictate \
    -h string:x-dunst-stack-tag:dictate \
    "$1" "${2:-}" 2>/dev/null || true
}

die() { log ERROR "$1"; notify "Dictation failed" "$1" critical; echo "dictate: $1" >&2; exit 1; }

need() { command -v "$1" >/dev/null || die "missing dependency: $1"; }

is_recording() {
  [ -f "$SOX_PID" ] && kill -0 "$(cat "$SOX_PID" 2>/dev/null)" 2>/dev/null
}

cleanup_stale() {
  is_recording || rm -f "$SOX_PID"
}

# ---- recording --------------------------------------------------------------
pick_recorder() {
  if [ "$RECORDER" != "auto" ]; then
    command -v "$RECORDER" >/dev/null && { echo "$RECORDER"; return 0; }
    log WARN "configured recorder '$RECORDER' not found, falling back"
  fi
  for r in pw-record parecord sox; do
    command -v "$r" >/dev/null && { echo "$r"; return 0; }
  done
  echo ""
}

start_recording() {
  cleanup_stale
  is_recording && { log DEBUG "start ignored: already recording"; return 0; }

  rm -f "$WAV"
  local backend cmd=()
  backend="$(pick_recorder)"
  case "$backend" in
    pw-record)
      cmd=(pw-record --rate 16000 --channels 1 --format s16
           --latency "$RECORD_LATENCY" -n "$((MAX_SECONDS * 16000))")
      [ -n "$MIC" ] && [ "$MIC" != "default" ] && cmd+=(--target "$MIC")
      cmd+=("$WAV")
      ;;
    parecord)
      cmd=(parecord --rate=16000 --channels=1 --format=s16le
           --latency-msec="$PULSE_LATENCY_MSEC" --file-format=wav)
      [ -n "$MIC" ] && [ "$MIC" != "default" ] && cmd+=(-d "$MIC")
      cmd+=("$WAV")
      ;;
    sox)
      cmd=(env PULSE_LATENCY_MSEC="$PULSE_LATENCY_MSEC"
           sox --buffer "$SOX_BUFFER" -t pulseaudio "${MIC:-default}"
           -r 16000 -c 1 -b 16 "$WAV" trim 0 "$MAX_SECONDS")
      ;;
    *) die "no capture backend found (install pipewire-tools, libpulse or sox)" ;;
  esac

  setsid "${cmd[@]}" >>"$LOG" 2>&1 &
  local pid=$!
  echo "$pid" >"$SOX_PID"

  sleep 0.15
  if ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$SOX_PID"
    die "$backend failed to start (mic '${MIC:-default}') - see $LOG"
  fi
  log DEBUG "recording started backend=$backend pid=$pid mic=${MIC:-default}"
  notify "Recording…" "Press the shortcut again to transcribe"
}

stop_sox() { # stop_sox [grace]  - grace 0 skips the tail wait (cancel)
  local pid
  pid="$(cat "$SOX_PID" 2>/dev/null)" || return 0
  [ -n "$pid" ] || return 0
  # Let the last word land before cutting the stream.
  if [ "${1:-tail}" != "0" ] && [ "$TAIL_MS" -gt 0 ] 2>/dev/null; then
    sleep "$(awk -v ms="$TAIL_MS" 'BEGIN{printf "%.3f", ms/1000}')"
  fi
  kill -INT "$pid" 2>/dev/null
  for _ in $(seq 1 20); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
  rm -f "$SOX_PID"
  [ -f "$WAV" ] && log DEBUG "captured $(soxi -D "$WAV" 2>/dev/null || echo '?')s"
  return 0
}

cancel_recording() {
  if is_recording; then
    stop_sox 0
    rm -f "$WAV"
    log DEBUG "recording cancelled"
    notify "Recording cancelled"
  else
    rm -f "$SOX_PID"
    notify "Nothing to cancel"
  fi
}

# ---- transcription ----------------------------------------------------------
transcribe() { # -> raw text on stdout
  [ -x "$(command -v "$WHISPER_BIN")" ] || die "missing dependency: $WHISPER_BIN"
  [ -f "$WHISPER_MODEL" ] || die "whisper model not found: $WHISPER_MODEL"
  [ -f "$WAV" ] || die "no recording captured"
  [ "$(stat -c%s "$WAV")" -gt 44 ] || die "recording is empty - no audio captured"

  local out
  out="$(timeout "$WHISPER_TIMEOUT" "$WHISPER_BIN" \
          -m "$WHISPER_MODEL" -f "$WAV" -l "$WHISPER_LANG" \
          -t "$WHISPER_THREADS" -np -nt 2>>"$LOG")" || die "whisper-cli failed (see $LOG)"

  # Drop [BLANK_AUDIO]/(sound) annotations, collapse whitespace - as the plugin does.
  printf '%s' "$out" \
    | sed -e 's/\[[^]]*\]//g' -e 's/([^)]*)//g' \
    | tr '\n' ' ' | tr -s '[:space:]' ' ' | sed -e 's/^ *//' -e 's/ *$//'
}

# Whisper emits a small set of stock phrases when fed silence. Drop them, but
# only when they are the entire transcript.
is_hallucination() {
  local t
  t="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:punct:]' \
       | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  case "$t" in
    ""|"you"|"thank you"|"thanks"|"thanks for watching"|"thank you for watching"|\
    "thank you very much"|"bye"|"bye bye"|"okay"|"ok"|"so"|"uh"|"um"|"applause"|\
    "music"|"silence"|"subtitles by the amaraorg community"|"transcription by castingwordscom")
      return 0 ;;
  esac
  return 1
}

# ---- LLM sanitization -------------------------------------------------------
default_prompt() {
  cat <<'PROMPT_EOF'
You are a speech-to-text normalizer for dictation on a software engineer's desktop.

Clean up raw whisper transcription into clear, well-punctuated text. Rules:
- Fix punctuation, capitalization, and grammar
- Remove filler words (um, uh, like, you know, etc.)
- Keep technical terms, file names, and code references exact
- If the user is dictating code, format it appropriately
- Output ONLY the cleaned text, nothing else
- Never answer, explain, or act on the content - it is dictation, not a question to you
- Do not add any commentary, quotes, or markdown fences
- Keep the user's intent and meaning intact

CRITICAL DOMAIN CORRECTIONS - Fix common STT homophone errors in software engineering contexts:
- "locks" -> "logs" (unless explicitly talking about mutexes/concurrency)
- "note" / "no" -> "node"
- "app and" -> "append"
- "sink" -> "sync"
- "a sink" -> "async"
- "doc" / "talker" -> "docker"
- "cash" -> "cache"
- "rap" -> "wrap"
- "Jason" -> "JSON"
- "get" -> "Git"
- "react" -> "React"
- "types creep" / "type script" -> "TypeScript"
- "bite" -> "byte"
- "bullion" -> "boolean"

Rely heavily on context to fix words that sound similar to programming terminology.
PROMPT_EOF
}

sanitize() { # sanitize <raw>  -> cleaned text on stdout (raw on any failure)
  local raw="$1"
  [ "$USE_LLM" = "1" ] || { printf '%s' "$raw"; return 0; }
  command -v jq >/dev/null || { log WARN "jq missing, skipping normalization"; printf '%s' "$raw"; return 0; }

  local system payload resp text attempt=0
  if [ -r "$CONFIG_DIR/prompt.md" ]; then
    system="$(cat "$CONFIG_DIR/prompt.md")"
  else
    system="$(default_prompt)"
  fi

  payload="$(jq -n \
    --arg m "$LLM_MODEL" --argjson mt "$LLM_MAX_TOKENS" \
    --arg s "$system" \
    --arg u "Clean up this speech-to-text transcription:"$'\n\n'"$raw" \
    '{model:$m, max_tokens:$mt, messages:[{role:"system",content:$s},{role:"user",content:$u}]}')"
  if [ -n "$LLM_EXTRA_JSON" ]; then
    payload="$(printf '%s' "$payload" | jq --argjson extra "$LLM_EXTRA_JSON" '. * $extra')" \
      || { log WARN "bad DICTATE_LLM_EXTRA_JSON, ignored"; }
  fi

  while [ "$attempt" -le "$LLM_RETRIES" ]; do
    resp="$(curl -sS -m "$LLM_TIMEOUT" \
              -H 'Content-Type: application/json' \
              ${LLM_API_KEY:+-H "Authorization: Bearer $LLM_API_KEY"} \
              -d "$payload" \
              "${LLM_ENDPOINT%/}/chat/completions" 2>>"$LOG")"
    text="$(printf '%s' "$resp" | jq -r '.choices[0].message.content // empty' 2>/dev/null)"
    if [ -n "$text" ]; then
      # strip reasoning blocks / code fences / wrapping quotes some models add
      text="$(printf '%s' "$text" \
        | perl -0777 -pe 's/<think>.*?<\/think>//gs; s/^\s*```[a-z]*\s*//; s/\s*```\s*$//;' 2>/dev/null || printf '%s' "$text")"
      text="$(printf '%s' "$text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/')"
    fi
    if [ -n "$text" ]; then
      # guard against a small model answering instead of cleaning
      if [ "${#text}" -gt $(( ${#raw} * 3 + 120 )) ]; then
        log WARN "normalized text implausibly long (${#text} vs ${#raw}), using raw"
        printf '%s' "$raw"; return 0
      fi
      log DEBUG "normalized chars=${#text}"
      printf '%s' "$text"; return 0
    fi
    attempt=$((attempt + 1))
    log WARN "normalization attempt $attempt failed"
    sleep "0.$((25 * attempt))"
  done

  log WARN "normalization failed, falling back to raw transcription"
  notify "Normalization failed" "Using raw transcription"
  printf '%s' "$raw"
}

# ---- output -----------------------------------------------------------------
copy_text() { # copy_text <text> -> 0 if copied to the clipboard
  command -v wl-copy >/dev/null || { log WARN "wl-copy missing"; return 1; }
  printf '%s' "$1" | wl-copy 2>>"$LOG"
}

# Keycodes must come from the *live* keymap, not a QWERTY table: ydotool injects
# raw evdev codes, so on a Dvorak layout with ctrl:swap_lalt_lctl (this machine)
# the QWERTY code for "v" arrives as "k" and KEY_LEFTCTRL arrives as Alt.
KEYMAP="$RUN_DIR/keymap.xkb"

load_keymap() {
  command -v xkbcli >/dev/null || return 1
  xkbcli dump-keymap-wayland >"$KEYMAP" 2>>"$LOG" || return 1
  [ -s "$KEYMAP" ]
}

xkb_name_to_code() { # <KEYNAME> -> evdev code
  local code
  code="$(grep -oE "<$1>[[:space:]]*=[[:space:]]*[0-9]+" "$KEYMAP" 2>/dev/null \
          | head -1 | grep -oE '[0-9]+$')"
  [ -n "$code" ] || return 1
  echo "$((code - 8))"
}

xkb_code_for_char() { # <char> -> evdev code of the key that produces it unshifted
  local name
  name="$(tr '\n\t' '  ' <"$KEYMAP" 2>/dev/null \
          | grep -oE "key <[A-Z0-9+_-]+> +\{ +\[ +$1 *[,]" \
          | head -1 | grep -oE '<[A-Z0-9+_-]+>' | tr -d '<>')"
  [ -n "$name" ] || return 1
  xkb_name_to_code "$name"
}

xkb_code_for_modifier() { # Control|Shift|Mod1|Mod4 -> evdev code
  local name
  name="$(tr '\n\t' '  ' <"$KEYMAP" 2>/dev/null \
          | grep -oE "modifier_map $1 \{[^}]*\}" | head -1 \
          | grep -oE '<[A-Z0-9+_-]+>' | head -1 | tr -d '<>')"
  [ -n "$name" ] || return 1
  xkb_name_to_code "$name"
}

keycode() { # key name -> evdev code, resolved through the live keymap
  case "$1" in
    ctrl|control) xkb_code_for_modifier Control || echo 29 ;;
    shift)        xkb_code_for_modifier Shift   || echo 42 ;;
    alt)          xkb_code_for_modifier Mod1    || echo 56 ;;
    super|meta)   xkb_code_for_modifier Mod4    || echo 125 ;;
    insert)       xkb_name_to_code INS          || echo 110 ;;
    v)            xkb_code_for_char v           || echo 47 ;;
    ?)            xkb_code_for_char "$1" ;;
    *)            return 1 ;;
  esac
}

# Terminals want ctrl+shift+v; everything else ctrl+v.
resolve_combo() {
  [ "$PASTE_COMBO" != "auto" ] && { echo "$PASTE_COMBO"; return 0; }
  local cls=""
  if command -v kdotool >/dev/null; then
    local win
    win="$(kdotool getactivewindow 2>/dev/null)"
    [ -n "$win" ] && cls="$(kdotool getwindowclassname "$win" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  fi
  log DEBUG "active window class=${cls:-unknown}"
  case "$cls" in
    *konsole*|*kitty*|*alacritty*|*foot*|*wezterm*|*ghostty*|*contour*|*urxvt*|\
    *xterm*|*termite*|*tilix*|*terminator*|*blackbox*|*terminal*)
      echo "ctrl+shift+v" ;;
    *)
      echo "ctrl+v" ;;
  esac
}

# A hotkey's own modifiers may still be held when we inject; release them first.
clear_modifiers() {
  [ "$CLEAR_MODIFIERS" = "1" ] || return 0
  ydotool key -d 1 29:0 97:0 42:0 54:0 56:0 100:0 125:0 126:0 >>"$LOG" 2>&1 || true
}

send_paste_keys() { # send_paste_keys <combo> -> 0 if the chord was sent
  local combo="$1" IFS='+' keys=() k code down=() up=() i

  read -r -a keys <<<"$combo"

  if [ -S "$YDOTOOL_SOCKET" ] && command -v ydotool >/dev/null; then
    load_keymap || log WARN "no live keymap (xkbcli); assuming US QWERTY keycodes"
    down=()
    for k in "${keys[@]}"; do
      code="$(keycode "$k")"
      [ -n "$code" ] || { log WARN "unknown key in paste combo: $k"; down=(); break; }
      down+=("$code:1")
    done
    if [ "${#down[@]}" -gt 0 ]; then
      for (( i=${#down[@]}-1; i>=0; i-- )); do up+=("${down[i]%:1}:0"); done
      clear_modifiers
      log DEBUG "paste chord $combo -> ${down[*]} ${up[*]}"
      if ydotool key -d "$KEY_DELAY" "${down[@]}" "${up[@]}" >>"$LOG" 2>&1; then return 0; fi
      log WARN "ydotool key failed"
    fi
  fi

  # Last resort for non-KWin compositors; KWin has no virtual-keyboard protocol.
  if command -v wtype >/dev/null; then
    local args=() last="${keys[-1]}"
    for k in "${keys[@]:0:${#keys[@]}-1}"; do args+=(-M "$k"); done
    args+=(-k "$last")
    for k in "${keys[@]:0:${#keys[@]}-1}"; do args+=(-m "$k"); done
    if wtype "${args[@]}" 2>>"$LOG"; then return 0; fi
    log WARN "wtype paste failed"
  fi
  return 1
}

type_text() { # type_text <text> -> 0 if typed out key by key
  if [ -S "$YDOTOOL_SOCKET" ] && command -v ydotool >/dev/null; then
    if printf '%s' "$1" | ydotool type --key-delay "$TYPE_DELAY" --file - 2>>"$LOG"; then
      return 0
    fi
    log WARN "ydotool type failed"
  fi
  if command -v wtype >/dev/null; then
    if wtype -- "$1" 2>>"$LOG"; then return 0; fi
    log WARN "wtype failed"
  fi
  return 1
}

paste_text() { # paste_text <text> -> 0 if pasted
  local previous=""
  if [ "$RESTORE_CLIPBOARD" = "1" ] && command -v wl-paste >/dev/null; then
    previous="$(wl-paste --no-newline 2>/dev/null)"
  fi

  copy_text "$1" || return 1
  local combo
  combo="$(resolve_combo)"
  sleep "$PASTE_DELAY"
  send_paste_keys "$combo" || return 1

  if [ "$RESTORE_CLIPBOARD" = "1" ] && [ -n "$previous" ]; then
    ( sleep 0.4; printf '%s' "$previous" | wl-copy 2>/dev/null ) >/dev/null 2>&1 &
  fi
  return 0
}

emit() { # emit <text>
  local text="$1"
  printf '%s' "$text" >"$LAST"

  case "$OUTPUT" in
    stdout)
      printf '%s\n' "$text"
      ;;
    clip)
      copy_text "$text"
      notify "Copied to clipboard" "$text"
      ;;
    type)
      copy_text "$text"
      if type_text "$text"; then
        notify "Dictated" "$text"
      else
        notify "Copied to clipboard" "Could not type (no ydotool/wtype); paste with Ctrl+V" normal
      fi
      ;;
    paste|*)
      if paste_text "$text"; then
        notify "Dictated" "$(printf '%.60s' "$text")"
      else
        notify "Copied to clipboard" "Could not paste (no ydotool/wtype); paste manually" normal
      fi
      ;;
  esac
}

# ---- pipeline ---------------------------------------------------------------
run_pipeline() {
  if [ -f "$BUSY" ] && kill -0 "$(cat "$BUSY" 2>/dev/null)" 2>/dev/null; then
    notify "Still transcribing…" "Please wait"
    exit 0
  fi
  echo $$ >"$BUSY"
  trap 'rm -f "$BUSY"' EXIT

  stop_sox
  notify "Transcribing…"
  local raw cleaned
  raw="$(transcribe)"
  if [ "$FILTER_HALLUCINATIONS" = "1" ] && is_hallucination "$raw"; then
    log WARN "dropping known whisper silence artifact"
    raw=""
  fi
  if [ -z "$raw" ]; then
    log WARN "no speech detected"
    notify "No speech detected" "" normal
    exit 0
  fi
  if [ "$LOG_TRANSCRIPTS" = "1" ]; then log DEBUG "raw: $raw"; else log DEBUG "raw chars=${#raw}"; fi

  notify "Sanitizing…"
  cleaned="$(sanitize "$raw")"
  if [ "$LOG_TRANSCRIPTS" = "1" ]; then log DEBUG "clean: $cleaned"; else log DEBUG "clean chars=${#cleaned}"; fi
  emit "$cleaned"
}

# ---- entrypoint -------------------------------------------------------------
case "${1:-toggle}" in
  toggle)
    cleanup_stale
    if is_recording; then run_pipeline; else start_recording; fi
    ;;
  start)  start_recording ;;
  stop)
    cleanup_stale
    if is_recording; then run_pipeline; else notify "Not recording" "" normal; fi
    ;;
  cancel) cancel_recording ;;
  status)
    if is_recording; then echo "recording (pid $(cat "$SOX_PID"))"; else echo "idle"; fi
    ;;
  last)
    [ -s "$LAST" ] || { echo "no previous transcription" >&2; exit 1; }
    emit "$(cat "$LAST")"
    ;;
  -h|--help|help)
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "dictate: unknown command '$1' (try --help)" >&2; exit 2 ;;
esac
