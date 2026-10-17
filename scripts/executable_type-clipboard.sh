#!/usr/bin/env bash
# type-clipboard.sh - "paste" the clipboard by typing it as fake keystrokes.
#
# For remote sessions that don't support pasting (serial consoles, IPMI/iDRAC
# KVMs, VNC, VMs without guest additions, ...). Wayland-native, so it works
# under KWin on Plasma where xdotool cannot.
#
# Backends:
#   wtype   - uploads its own keymap over the Wayland virtual-keyboard protocol,
#             so the active layout is irrelevant and Unicode works. Preferred.
#   ydotool - injects raw evdev keycodes via uinput. ydotool's own 'type'
#             command assumes a QWERTY layout and produces garbage on anything
#             else, so this script does NOT use it: it compiles the keymap that
#             is actually loaded (xkbcli) and derives the keycode + modifier
#             level for every character itself. Works on Dvorak, Colemak and
#             custom layouts alike.
#
# The keystrokes go to whatever window has focus, so bind this to a global
# shortcut (System Settings > Keyboard > Shortcuts > Add Command) and press it
# while the target window is focused, or use -w for a countdown.
#
# With one or more text arguments, types that text instead of the clipboard.
#
# Caveat: this reproduces characters as interpreted by the LOCAL keymap. That
# covers terminals, browsers and HTML5 KVM consoles. A client that forwards raw
# scancodes to the remote end (some VNC/SPICE/RDP setups) will apply the REMOTE
# layout instead - there, match the layouts on both ends.

set -uo pipefail
KEY_DELAY=10         # ms between key events; raise for laggy/slow consoles
WAIT=0                # seconds to wait before typing
ENTER=0               # send a trailing Enter
SELECTION=clipboard   # or 'primary'
BACKEND=auto          # auto | wtype | ydotool
DRY=0
NOTIFY=1
STRIP_TABS=0

self=${0##*/}
sleep 0.5
die() {
    printf '%s: %s\n' "$self" "$1" >&2
    [ "$NOTIFY" = 1 ] && command -v notify-send >/dev/null &&
        notify-send -a type-clipboard -u critical "type-clipboard" "$1"
    exit 1
}

warn() { printf '%s: %s\n' "$self" "$1" >&2; }

usage() {
    cat <<EOF
Usage: $self [options] [TEXT...]

Types TEXT (if given; multiple words are joined with spaces) or the clipboard
contents into the focused window as keystrokes.

Options:
  -d, --delay MS     delay between key events (default: $KEY_DELAY; raise to 25-40
                     over slow SSH/serial links if characters get dropped)
  -w, --wait SEC     wait SEC seconds before typing, to focus the target window
  -p, --primary      use the primary selection (middle-click) instead of clipboard
  -n, --enter        send a trailing Enter after the text
  -t, --tabs-to-spaces N
                     replace tabs with N spaces (avoids triggering completion in
                     shells and auto-indent in editors)
  -b, --backend B    auto (default), wtype, or ydotool
  -N, --no-notify    never use desktop notifications
      --dry-run      show what would be typed and how it maps, type nothing
  -h, --help         this help

Notes:
  * Trailing newlines are stripped, so a copied command is not auto-executed.
    Use -n if you do want it submitted.
  * The ydotool backend can only produce characters that exist somewhere in the
    active keymap (levels 1-4). Anything else is transliterated to ASCII
    ("smart quotes" -> "straight", cafe' -> cafe) with a warning. wtype has no
    such limit.
EOF
}

ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        -d|--delay)    KEY_DELAY="${2:?missing value for $1}"; shift 2 ;;
        -w|--wait)     WAIT="${2:?missing value for $1}"; shift 2 ;;
        -t|--tabs-to-spaces) STRIP_TABS="${2:?missing value for $1}"; shift 2 ;;
        -b|--backend)  BACKEND="${2:?missing value for $1}"; shift 2 ;;
        -p|--primary)  SELECTION=primary; shift ;;
        -n|--enter)    ENTER=1; shift ;;
        -N|--no-notify) NOTIFY=0; shift ;;
        --dry-run)     DRY=1; shift ;;
        -h|--help)     usage; exit 0 ;;
        --)            shift
                       while [ $# -gt 0 ]; do ARGS+=("$1"); shift; done ;;
        *)             ARGS+=("$1"); shift ;;
    esac
done

# --- get the text -----------------------------------------------------------
if [ ${#ARGS[@]} -gt 0 ]; then
    text="${ARGS[*]}"
else
    command -v wl-paste >/dev/null || die "wl-paste not found (install wl-clipboard)"
    paste_args=(--no-newline)
    [ "$SELECTION" = primary ] && paste_args+=(--primary)
    text=$(wl-paste "${paste_args[@]}" 2>/dev/null)
    [ -n "$text" ] || die "$SELECTION is empty (or holds non-text data)"
fi

# CRLF -> LF, then strip trailing whitespace so nothing is auto-submitted
text=${text//$'\r'/}
while [ "$text" != "${text%[$' \t\n']}" ]; do text=${text%[$' \t\n']}; done

if [ "$STRIP_TABS" -gt 0 ] 2>/dev/null; then
    spaces=$(printf "%${STRIP_TABS}s" '')
    text=${text//$'\t'/$spaces}
fi

chars=${#text}

# --- pick a backend ---------------------------------------------------------
have_wtype() {
    command -v wtype >/dev/null || return 1
    # probe the exact invocation used below; empty stdin types nothing
    printf '' | wtype -d 1 - >/dev/null 2>&1
}

case "$BACKEND" in
    auto)    have_wtype && BACKEND=wtype || BACKEND=ydotool ;;
    wtype)   command -v wtype >/dev/null || die "wtype not installed" ;;
    ydotool) ;;
    *)       die "unknown backend '$BACKEND' (auto|wtype|ydotool)" ;;
esac

# --- ydotool backend: translate text into keycodes via the live keymap ------
# Emits one line of 'keycode:state' events per batch of characters, with
# modifiers always released at the end of a line.
xkb_events() {
    local rules=evdev model=pc105 layout='' variant='' options='' group=0 q g

    if command -v setxkbmap >/dev/null &&
       q=$(setxkbmap -query 2>/dev/null) && [ -n "$q" ]; then
        rules=$(sed -n 's/^rules: *//p'   <<<"$q"); rules=${rules:-evdev}
        model=$(sed -n 's/^model: *//p'   <<<"$q"); model=${model:-pc105}
        layout=$(sed -n 's/^layout: *//p' <<<"$q")
        variant=$(sed -n 's/^variant: *//p' <<<"$q")
        options=$(sed -n 's/^options: *//p' <<<"$q")
    fi
    if [ -z "$layout" ] && [ -r ~/.config/kxkbrc ]; then
        layout=$(sed -n 's/^LayoutList=//p'  ~/.config/kxkbrc)
        variant=$(sed -n 's/^VariantList=//p' ~/.config/kxkbrc)
        options=$(sed -n 's/^Options=//p'     ~/.config/kxkbrc)
    fi
    [ -n "$layout" ] || layout=us

    # which layout group is active right now (multi-layout setups)
    if command -v gdbus >/dev/null; then
        g=$(gdbus call --session --dest org.kde.KWin --object-path /Layouts \
              --method org.kde.KeyboardLayouts.getLayout 2>/dev/null |
            grep -oP 'uint32 \K\d+') && [ -n "$g" ] && group=$g
    fi

    python3 -c "$PYSRC" "$rules" "$model" "$layout" "$variant" "$options" "$group"
}

PYSRC='
import os, re, subprocess, sys

rules, model, layout, variant, options, group = sys.argv[1:7]
group = int(group or 0)

# with several layouts configured, compile only the active one
if "," in layout:
    ls, vs = layout.split(","), (variant.split(",") + [""] * 9)
    if group < len(ls):
        layout, variant = ls[group], vs[group]

cmd = ["xkbcli", "compile-keymap", "--rules", rules, "--model", model,
       "--layout", layout]
if variant:
    cmd += ["--variant", variant]
if options:
    cmd += ["--options", options]
try:
    km = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
except Exception as e:
    sys.exit("cannot compile keymap (%s %s): %s" % (layout, variant, e))

NAMED = {
    "space": " ", "exclam": "!", "quotedbl": "\"", "numbersign": "#",
    "dollar": "$", "percent": "%", "ampersand": "&", "apostrophe": "'"'"'",
    "parenleft": "(", "parenright": ")", "asterisk": "*", "plus": "+",
    "comma": ",", "minus": "-", "period": ".", "slash": "/",
    "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
    "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
    "colon": ":", "semicolon": ";", "less": "<", "equal": "=",
    "greater": ">", "question": "?", "at": "@", "bracketleft": "[",
    "backslash": "\\", "bracketright": "]", "asciicircum": "^",
    "underscore": "_", "grave": "`", "braceleft": "{", "bar": "|",
    "braceright": "}", "asciitilde": "~", "Return": "\n", "Tab": "\t",
}

codes = dict(re.findall(r"<(\w+)>\s*=\s*(\d+);", km))
cands = {}
for name, body in re.findall(r"key\s+<(\w+)>\s*\{(.*?)\};", km, re.S):
    if name not in codes:
        continue
    m = re.search(r"symbols\[(?:Group)?1\]\s*=\s*\[([^\]]*)\]", body)
    if not m:
        m = re.search(r"\[([^\]]*)\]", body)
    if not m:
        continue
    kc = int(codes[name]) - 8
    keypad = name.startswith("KP")
    for level, sym in enumerate([s.strip() for s in m.group(1).split(",")], 1):
        if level > 4:
            break
        if len(sym) == 1:
            ch = sym
        elif sym in NAMED:
            ch = NAMED[sym]
        elif re.fullmatch(r"U[0-9A-Fa-f]{4,6}", sym):
            ch = chr(int(sym[1:], 16))
        else:
            continue
        # prefer the main block over the keypad, then the lowest level
        cands.setdefault(ch, []).append((keypad, level, kc))

charmap = {c: min(v) for c, v in cands.items()}

text = sys.stdin.read()

# characters the keymap cannot produce: transliterate, then drop what is left
if any(c not in charmap for c in text):
    import unicodedata
    out, dropped = [], []
    for c in text:
        if c in charmap:
            out.append(c)
            continue
        alt = unicodedata.normalize("NFKD", c)
        alt = "".join(a for a in alt if not unicodedata.combining(a))
        alt = {"“": "\"", "”": "\"", "‘": "'"'"'",
               "’": "'"'"'", "–": "-", "—": "--",
               "…": "...", " ": " "}.get(c, alt)
        if alt and all(a in charmap for a in alt):
            out.append(alt)
        else:
            dropped.append(c)
    if dropped:
        sys.stderr.write("dropped %d untypeable character(s): %s\n"
                         % (len(dropped), "".join(sorted(set(dropped)))))
    text = "".join(out)

SHIFT, ALTGR = 42, 100          # KEY_LEFTSHIFT, KEY_RIGHTALT
if os.environ.get("DUMP_MAP"):
    for c in text:
        kp, level, kc = charmap[c]
        print("%-8r keycode=%-4d level=%d" % (c, kc, level))
    sys.exit(0)

BATCH = 96
line, held, n = [], set(), 0
for c in text:
    _, level, kc = charmap[c]
    want = set()
    if level in (2, 4):
        want.add(SHIFT)
    if level in (3, 4):
        want.add(ALTGR)
    for m in held - want:
        line.append("%d:0" % m)
    for m in want - held:
        line.append("%d:1" % m)
    held = want
    line += ["%d:1" % kc, "%d:0" % kc]
    n += 1
    if n >= BATCH:
        line += ["%d:0" % m for m in held]      # never leave a modifier held
        print(" ".join(line))
        line, held, n = [], set(), 0
line += ["%d:0" % m for m in held]
if line:
    print(" ".join(line))
'

# --- dry run ----------------------------------------------------------------
if [ "$DRY" = 1 ]; then
    lines=$(grep -c '' <<<"$text")
    printf -- '--- backend: %s | %d chars, %d line(s), delay %sms ---\n' \
        "$BACKEND" "$chars" "$lines" "$KEY_DELAY"
    printf '%s\n' "$text"
    if [ "$BACKEND" = ydotool ]; then
        printf -- '--- keycode mapping ---\n'
        printf '%s' "$text" | DUMP_MAP=1 xkb_events
    fi
    exit 0
fi

# --- countdown --------------------------------------------------------------
if [ "$WAIT" != 0 ]; then
    if [ "$NOTIFY" = 1 ] && command -v notify-send >/dev/null; then
        notify-send -a type-clipboard -t $(( ${WAIT%.*} * 1000 + 500 )) \
            "Typing in ${WAIT}s" "$chars chars, focus the target window"
    fi
    sleep "$WAIT"
fi

# --- type -------------------------------------------------------------------
if [ "$BACKEND" = wtype ]; then
    printf '%s' "$text" | wtype -d "$KEY_DELAY" - || die "wtype failed"
    [ "$ENTER" = 1 ] && wtype -k Return
    exit 0
fi

command -v ydotool >/dev/null || die "ydotool not found"
command -v xkbcli  >/dev/null || die "xkbcli not found (install libxkbcommon)"
command -v python3 >/dev/null || die "python3 not found"

socket="${YDOTOOL_SOCKET:-/run/user/$(id -u)/.ydotool_socket}"
export YDOTOOL_SOCKET="$socket"

if [ ! -S "$socket" ]; then
    [ -w /dev/uinput ] || die "no write access to /dev/uinput - ydotoold cannot start"
    command -v ydotoold >/dev/null || die "ydotoold not found"
    # normally ydotoold.service has it running already; this is the fallback
    if ! systemctl --user start ydotoold.service >/dev/null 2>&1; then
        setsid ydotoold -p "$socket" -P 0600 >/dev/null 2>&1 &
    fi
    for _ in $(seq 40); do
        [ -S "$socket" ] && break
        sleep 0.1
    done
    [ -S "$socket" ] || die "ydotoold did not come up at $socket"
    # let the compositor notice the new virtual keyboard, else the first
    # keystrokes are swallowed
    sleep 0.7
fi

events=$(printf '%s' "$text" | xkb_events) || die "could not map text to keycodes"
[ -n "$events" ] || die "nothing left to type"

# never leave shift/altgr stuck down if we are interrupted mid-paste
trap 'ydotool key 42:0 100:0 >/dev/null 2>&1' EXIT INT TERM

while IFS= read -r batch; do
    # shellcheck disable=SC2086  # deliberate word splitting: 'keycode:state'
    ydotool key --key-delay "$KEY_DELAY" $batch || die "ydotool failed to type"
done <<<"$events"

[ "$ENTER" = 1 ] && ydotool key --key-delay "$KEY_DELAY" 28:1 28:0

exit 0
