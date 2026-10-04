#!/usr/bin/env python3
"""Real-input test: runs the game in a real X11 window (Xvfb) and plays it with
OS-level mouse and keyboard events sent by xdotool - exactly what a player's
hardware produces. Verifies controls end to end (this is the gap that let the
broken key bindings of build 0.1.0 slip through: the old bot pressed actions
directly).

Usage: tools/real_input_test.py [--exe path/to/game_binary_or_godot] [--wine]
Writes systems/tests/output/real_input.json and screenshots in
systems/tests/output/real_input_*.png
"""
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "systems", "tests", "output")
STATE = os.path.join(OUT, "real_input_state.json")
DISPLAY = ":77"
W, H = 1600, 900
results = []


def sh(*args, check=False):
    return subprocess.run(args, env={**os.environ, "DISPLAY": DISPLAY}, capture_output=True, text=True, check=check)


def state():
    for _ in range(20):
        try:
            with open(STATE) as f:
                return json.load(f)
        except Exception:
            time.sleep(0.1)
    return {}


def wait_for(pred, timeout=10.0, step=0.2):
    end = time.time() + timeout
    s = {}
    while time.time() < end:
        s = state()
        try:
            if s and pred(s):
                return s
        except Exception:
            pass
        time.sleep(step)
    return None


def win_offset():
    r = sh("xdotool", "search", "--name", "Gloamreach")
    ids = r.stdout.split()
    if not ids:
        return 0, 0
    g = sh("xdotool", "getwindowgeometry", ids[0]).stdout
    x = y = 0
    for line in g.splitlines():
        if "Position:" in line:
            xy = line.split("Position:")[1].split("(")[0].strip().split(",")
            x, y = int(xy[0]), int(xy[1])
    return x, y


OFF = (0, 0)


def move(x, y):
    sh("xdotool", "mousemove", str(int(x + OFF[0])), str(int(y + OFF[1])))
    time.sleep(0.08)


def click(x, y, button=1):
    move(x, y)
    sh("xdotool", "click", str(button))
    time.sleep(0.15)


def key(k, hold=0.12):
    sh("xdotool", "keydown", k)
    time.sleep(hold)
    sh("xdotool", "keyup", k)
    time.sleep(0.15)


def button(s, text_part):
    for b in s.get("buttons", []):
        if text_part.lower() in b["text"].lower():
            return b
    return None


def shot(name):
    sh("import", "-window", "root", os.path.join(OUT, f"real_input_{name}.png"))


def record(tid, desc, ok, notes):
    results.append({"id": tid, "description": desc, "result": "PASS" if ok else "FAIL", "notes": notes})
    print(("PASS" if ok else "FAIL"), tid, desc, "-", notes, flush=True)


def main():
    global OFF
    os.makedirs(OUT, exist_ok=True)
    if os.path.exists(STATE):
        os.remove(STATE)
    exe = "godot"
    wine = "--wine" in sys.argv
    if "--exe" in sys.argv:
        exe = sys.argv[sys.argv.index("--exe") + 1]
    xvfb = subprocess.Popen(["Xvfb", DISPLAY, "-screen", "0", f"{W}x{H}x24"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.5)
    game_args = ["--rendering-driver", "opengl3", "--resolution", f"{W}x{H}", "--position", "0,0", "--", f"--state-file={STATE}"]
    if exe == "godot":
        cmd = ["godot", "--path", ROOT] + game_args
    elif wine:
        cmd = ["wine", exe] + game_args
    else:
        cmd = [exe] + game_args
    env = {**os.environ, "DISPLAY": DISPLAY}
    log = open(os.path.join(OUT, "real_input_game.log"), "w")
    game = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        s = wait_for(lambda s: s.get("screen") == "MainMenu", 40)
        OFF = win_offset()
        record("RI-01", "Main menu responds to the mouse", s is not None, f"window offset {OFF}")
        shot("01_menu")
        b = button(s or {}, "New Game")
        click(b["x"], b["y"])
        s = wait_for(lambda s: s.get("screen") == "CharacterSelect", 10)
        b = button(s or {}, "Begin as Seraphine")
        click(b["x"], b["y"])
        s = wait_for(lambda s: s.get("playing") and "player" in s, 20)
        record("RI-02", "Start a new game with mouse clicks", s is not None, "New Game -> Begin as Seraphine clicked")
        time.sleep(1.5)
        shot("02_ingame")

        # --- WASD
        s0 = state()
        key("w", 1.5)
        time.sleep(0.8)
        s1 = state()
        dz = s0["player"]["pos"][2] - s1["player"]["pos"][2]
        record("RI-03", "W key moves the heroine", dz > 1.0, f"moved {dz:.2f} m north")

        # --- click on Ivenn: walk there and talk (click-to-interact)
        s = state()
        iv = s["npcs"][0]
        click(*iv["screen"])
        time.sleep(0.6)
        s = wait_for(lambda s: s["windows"]["dialogue"], 12)
        record("RI-04", "Left-click on NPC walks to him and opens dialogue", s is not None, f"dialogue node {s and s['dialogue_node']}")
        shot("03_dialogue")
        if s:
            b = button(s, "How can I help")
            click(b["x"], b["y"])
            s = wait_for(lambda s: s["dialogue_node"] == "offer", 5)
            b = button(s or {}, "Accept quest")
            if b:
                click(b["x"], b["y"])
            s = wait_for(lambda s: s.get("quests", {}).get("q_ashen_toll") == "active", 5)
            record("RI-05", "Accept the quest by clicking dialogue options", s is not None, "quest q_ashen_toll active")

        # --- E key near Ivenn reopens dialogue
        key("e")
        s = wait_for(lambda s: s["windows"]["dialogue"], 5)
        record("RI-06", "E key talks to the NPC", s is not None, f"node {s and s['dialogue_node']}")
        if s:
            b = button(s, "on my way") or button(s, "Farewell")
            click(b["x"], b["y"])
            wait_for(lambda s: not s["windows"]["dialogue"], 5)

        # --- I key / HUD button / Esc
        key("i")
        s = wait_for(lambda s: s["windows"]["inventory"], 5)
        record("RI-07", "I key opens the inventory", s is not None, "")
        shot("04_inventory")
        key("i")
        wait_for(lambda s: not s["windows"]["inventory"], 5)
        s = state()
        b = button(s, "Bag (I)")
        click(b["x"], b["y"])
        s = wait_for(lambda s: s["windows"]["inventory"], 5)
        record("RI-08", "HUD 'Bag' button opens the inventory with the mouse", s is not None, "")
        key("Escape")
        s = wait_for(lambda s: not s["windows"]["inventory"], 5)
        for label, wid in [("Hero (C)", "character"), ("Skills (K)", "skills"), ("Quests (J)", "quests"), ("Map (M)", "map")]:
            st = state()
            b = button(st, label)
            click(b["x"], b["y"])
            ok = wait_for(lambda s, w=wid: s["windows"][w], 5) is not None
            record(f"RI-09-{wid}", f"HUD '{label}' button works", ok, "")
            key("Escape")
            wait_for(lambda s, w=wid: not s["windows"][w], 5)

        # --- click on the ground: walk there
        s = state()
        px, py = s["player"]["screen"]
        start = s["player"]["pos"]
        click(px - 250, py + 120)
        time.sleep(2.0)
        s = state()
        moved = ((s["player"]["pos"][0] - start[0]) ** 2 + (s["player"]["pos"][2] - start[2]) ** 2) ** 0.5
        record("RI-10", "Left-click on the ground walks there (Sacred-style)", moved > 1.0, f"moved {moved:.1f} m toward the click")

        # --- go near the Sentinels on the road (keyboard), then click an enemy
        for _ in range(12):
            s = state()
            e = s["enemies"][0]
            if e["dist"] < 14:
                break
            # click toward the nearest enemy to approach it (ground click)
            ex, ey = e["screen"] if e["screen"] else (px, py)
            click((ex + s["player"]["screen"][0]) / 2, (ey + s["player"]["screen"][1]) / 2)
            time.sleep(1.5)
        s = state()
        kills0 = s["player"]["kills"]
        e = s["enemies"][0]
        shot("05_before_attack")
        # click the enemy repeatedly like a player would until it dies
        dealt = False
        for i in range(40):
            s = state()
            if s["player"]["kills"] > kills0:
                break
            if not s["enemies"]:
                break
            tgt = s["enemies"][0]
            if tgt["screen"]:
                click(*tgt["screen"])
            if i % 6 == 3:
                key("1")   # skill on hotkey 1
            if s["player"]["health"] < s["player"]["max_health"] * 0.4:
                key("q")
            time.sleep(0.35)
            if tgt["hp"] < 60:
                dealt = True
        s = state()
        shot("06_after_attack")
        record("RI-11", "Left-click on an enemy attacks it until it dies", s["player"]["kills"] > kills0, f"kills {kills0} -> {s['player']['kills']}")
        record("RI-12", "Key 1 casts the first skill", s["counters"]["skills"] > 0, f"skills cast: {s['counters']['skills']}")

        # --- Space dodge and right-click heavy attack
        d0 = state()["counters"]["dodges"]
        key("space", 0.3)
        time.sleep(0.8)
        record("RI-13", "Space dodges", state()["counters"]["dodges"] > d0, "")
        h0 = state()["counters"]["heavies"]
        s = state()
        move(s["player"]["screen"][0] + 80, s["player"]["screen"][1] - 40)
        for _ in range(3):
            sh("xdotool", "mousedown", "3")
            time.sleep(0.4)
            sh("xdotool", "mouseup", "3")
            time.sleep(1.2)
            if state()["counters"]["heavies"] > h0:
                break
        record("RI-14", "Right-click performs a heavy attack", state()["counters"]["heavies"] > h0, "")

        # --- Esc pause menu and resume by clicking
        key("Escape")
        s = wait_for(lambda s: s["paused"], 5)
        shot("07_pause")
        ok = s is not None
        if s:
            b = button(s, "Resume")
            click(b["x"], b["y"])
            ok = wait_for(lambda s: not s["paused"], 5) is not None
        record("RI-15", "Esc opens the pause menu, clicking Resume continues", ok, "")
    finally:
        game.terminate()
        try:
            game.wait(10)
        except Exception:
            game.kill()
        xvfb.terminate()
        log.close()
    passed = sum(1 for r in results if r["result"] == "PASS")
    with open(os.path.join(OUT, "real_input.json"), "w") as f:
        json.dump({"date": time.strftime("%Y-%m-%d %H:%M:%S"), "binary": exe, "wine": wine, "passed": passed, "total": len(results), "results": results}, f, indent=2)
    print(f"REAL INPUT: {passed}/{len(results)} passed")
    sys.exit(0 if passed == len(results) else 1)


if __name__ == "__main__":
    main()
