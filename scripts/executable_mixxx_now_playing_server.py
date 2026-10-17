#!/usr/bin/env python3
import subprocess
import os
import json
from flask import Flask, jsonify

app = Flask(__name__)

def detect_display_server():
    if os.getenv("WAYLAND_DISPLAY"):
        if subprocess.run([
    "which",
    "hyprctl"
], capture_output=True).returncode == 0:
            return "hyprland"
        else:
            return "wayland"
    elif os.getenv("DISPLAY"):
        revturn "x11"
    return "unknown"

def get_mixxx_title_x11():
    try:
        ids = subprocess.check_output([
    "xdotool",
    "search",
    "--name",
    "| Mixxx"
]).decode().split()
        for wid in ids:
            title = subprocess.check_output(["xdotool", "getwindowname", wid]).decode().strip()
            if "| Mixxx" in title:
                return title
    except subprocess.CalledProcessError:
        return None
    return None

def get_mixxx_title_hyprland():
    try:
        output = subprocess.check_output([
    "hyprctl",
    "-j",
    "clients"
], text=True)
        clients = json.loads(output)
        for client in clients:
            if client.get("class") == "org.mixxx.Mixxx":
                return client.get("title")
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        return None
    return None

def parse_title(full_title):
    if "| Mixxx" in full_title:
        full_title = full_title.replace("| Mixxx", "").strip()
    if "-" in full_title:
        artist, title = full_title.split("-", 1)
        return artist.strip(), title.strip()
    return None, None

@app.route("/now-playing", methods=[
    "GET"
])
def now_playing():
    backend = detect_display_server()
    if backend == "x11":
        full_title = get_mixxx_title_x11()
    elif backend == "hyprland":
        full_title = get_mixxx_title_hyprland()
    else:
        return jsonify({
    "error": "Unsupported display server"
}), 500

    if not full_title:
        return jsonify({
    "status": "Mixxx window not found"
}), 404
    print(full_title)
    artist, title = parse_title(full_title)
    if artist and title:
        return json.dumps({"artist": artist, "title": title}, ensure_ascii=False)
    else:
        return jsonify({
    "status": "Could not parse Mixxx title"
}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=39000)

