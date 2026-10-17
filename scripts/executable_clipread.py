#!/usr/bin/env python3
"""RSVP speed reader for the clipboard (same style as the ESP32 gadget).

Usage:
  clipread.py              read the clipboard
  clipread.py --primary    read the current selection (no copy needed)
  clipread.py -w 700       start at 700 wpm
  echo text | clipread.py -   read stdin

Keys:
  space / click        play / pause
  double-click, left   back 10 words     right  forward 10 words
  up / down            +/- 25 wpm        r      restart
  esc / q              quit
"""

import argparse
import re
import shutil
import subprocess
import sys
import tkinter as tk
import tkinter.font as tkfont

BG = "#111111"
FG = "#e8e8e8"
ORP_COLOR = "#ff5a4f"
DIM = "#555555"

WIDTH, HEIGHT = 720, 220
ORP_X = WIDTH * 0.38          # fixed x of the ORP letter's center
WORD_Y = HEIGHT * 0.52
MAX_FONT, MIN_FONT = 56, 22


def read_clipboard(primary: bool) -> str:
    if shutil.which("wl-paste"):
        cmd = ["wl-paste", "--no-newline"] + (["--primary"] if primary else [])
    elif shutil.which("xclip"):
        cmd = ["xclip", "-o", "-selection", "primary" if primary else "clipboard"]
    else:
        sys.exit("need wl-paste (wl-clipboard) or xclip")
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=2).stdout
    except subprocess.TimeoutExpired:
        return ""


def orp_index(n: int) -> int:
    if n <= 1:
        return 0
    if n <= 5:
        return 1
    if n <= 9:
        return 2
    if n <= 13:
        return 3
    return 4


def word_delay_ms(word: str, wpm: int) -> int:
    f = 1.0
    last = word.rstrip("\"')”’»")[-1:] or ""
    if last in ".!?":
        f = 2.0
    elif last in ",;:—–":
        f = 1.5
    if len(word) > 8:
        f += 0.3
    return int(60000 / wpm * f)


class Reader:
    def __init__(self, root: tk.Tk, words: list[str], wpm: int):
        self.root = root
        self.words = words
        self.wpm = wpm
        self.i = 0
        self.playing = False
        self.after_id = None
        self.click_id = None

        root.title("clipread")
        root.configure(bg=BG)
        root.geometry(f"{WIDTH}x{HEIGHT}")
        root.resizable(False, False)
        root.attributes("-topmost", True)

        self.c = tk.Canvas(root, width=WIDTH, height=HEIGHT, bg=BG,
                           highlightthickness=0)
        self.c.pack()

        family = next((f for f in ("Inter", "Noto Sans", "DejaVu Sans")
                       if f in tkfont.families()), "TkDefaultFont")
        self.fonts = {s: tkfont.Font(family=family, size=-s, weight="bold")
                      for s in range(MAX_FONT, MIN_FONT - 1, -2)}
        self.small = tkfont.Font(family=family, size=-14)

        root.bind("<space>", lambda e: self.toggle())
        root.bind("<Left>", lambda e: self.seek(-10))
        root.bind("<Right>", lambda e: self.seek(10))
        root.bind("<Up>", lambda e: self.set_wpm(self.wpm + 25))
        root.bind("<Down>", lambda e: self.set_wpm(self.wpm - 25))
        root.bind("r", lambda e: self.restart())
        for k in ("<Escape>", "q"):
            root.bind(k, lambda e: root.destroy())
        # single click toggles, double click jumps back (like the device)
        self.c.bind("<Button-1>", self.on_click)
        self.c.bind("<Double-Button-1>", self.on_double)

        self.draw()
        self.root.after(600, self.toggle)  # short lead-in, then play

    # ---- controls ---------------------------------------------------------
    def toggle(self):
        self.playing = not self.playing
        if self.playing:
            if self.i >= len(self.words) - 1:
                self.i = 0
            self.schedule(word_delay_ms(self.words[self.i], self.wpm))
        else:
            self.cancel()
        self.draw()

    def seek(self, delta: int):
        self.i = max(0, min(len(self.words) - 1, self.i + delta))
        if self.playing:
            self.cancel()
            self.schedule(word_delay_ms(self.words[self.i], self.wpm))
        self.draw()

    def set_wpm(self, wpm: int):
        self.wpm = max(100, min(1200, wpm))
        self.draw()

    def restart(self):
        self.i = 0
        self.seek(0)

    def on_click(self, _):
        if self.click_id:
            return
        self.click_id = self.root.after(250, self._single_click)

    def _single_click(self):
        self.click_id = None
        self.toggle()

    def on_double(self, _):
        if self.click_id:
            self.root.after_cancel(self.click_id)
            self.click_id = None
        self.seek(-10)

    # ---- playback ---------------------------------------------------------
    def schedule(self, ms: int):
        self.after_id = self.root.after(ms, self.tick)

    def cancel(self):
        if self.after_id:
            self.root.after_cancel(self.after_id)
            self.after_id = None

    def tick(self):
        self.after_id = None
        if self.i >= len(self.words) - 1:
            self.playing = False
            self.draw()
            return
        self.i += 1
        self.draw()
        self.schedule(word_delay_ms(self.words[self.i], self.wpm))

    # ---- drawing ----------------------------------------------------------
    def pick_font(self, pre: str, orp: str, word: str):
        for f in self.fonts.values():
            x0 = ORP_X - f.measure(pre) - f.measure(orp) / 2
            if x0 >= 16 and x0 + f.measure(word) <= WIDTH - 16:
                return f, x0
        f = self.fonts[MIN_FONT]
        return f, max(16, (WIDTH - f.measure(word)) / 2)

    def draw(self):
        c = self.c
        c.delete("all")
        word = self.words[self.i]
        k = orp_index(len(word))
        pre, orp, post = word[:k], word[k:k + 1], word[k + 1:]
        f, x = self.pick_font(pre, orp, word)

        # guide lines + ORP ticks
        top, bot = WORD_Y - 48, WORD_Y + 48
        c.create_line(0, top, WIDTH, top, fill=DIM)
        c.create_line(0, bot, WIDTH, bot, fill=DIM)
        c.create_line(ORP_X, top, ORP_X, top + 12, fill=DIM, width=2)
        c.create_line(ORP_X, bot - 12, ORP_X, bot, fill=DIM, width=2)

        c.create_text(x, WORD_Y, text=pre, font=f, fill=FG, anchor="w")
        x += f.measure(pre)
        c.create_text(x, WORD_Y, text=orp, font=f, fill=ORP_COLOR, anchor="w")
        x += f.measure(orp)
        c.create_text(x, WORD_Y, text=post, font=f, fill=FG, anchor="w")

        # progress bar
        n = len(self.words)
        frac = self.i / (n - 1) if n > 1 else 1
        c.create_rectangle(0, 0, WIDTH * frac, 4, fill=ORP_COLOR, width=0)

        # status line
        left_ms = sum(word_delay_ms(w, self.wpm) for w in self.words[self.i + 1:])
        mins, secs = divmod(round(left_ms / 1000), 60)
        state = "" if self.playing else "❚❚  paused   ·   "
        status = f"{state}{self.wpm} wpm   ·   {self.i + 1}/{n}   ·   {mins}:{secs:02d} left"
        c.create_text(WIDTH / 2, HEIGHT - 16, text=status, font=self.small,
                      fill=DIM)

        # when paused, show surrounding context
        if not self.playing:
            ctx = " ".join(self.words[max(0, self.i - 6):self.i + 7])
            c.create_text(WIDTH / 2, 22, text=ctx, font=self.small, fill=DIM,
                          width=WIDTH - 40)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", nargs="?", help="'-' to read stdin")
    ap.add_argument("-w", "--wpm", type=int, default=550)
    ap.add_argument("-p", "--primary", action="store_true",
                    help="read the primary selection instead of the clipboard")
    args = ap.parse_args()

    text = sys.stdin.read() if args.source == "-" else read_clipboard(args.primary)
    words = re.findall(r"\S+", text)
    if not words:
        words = ["(clipboard", "is", "empty)"]

    root = tk.Tk(className="clipread")
    Reader(root, words, args.wpm)
    root.mainloop()


if __name__ == "__main__":
    main()
