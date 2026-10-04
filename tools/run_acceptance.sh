#!/bin/bash
# Runs the full verification suite and regenerates TEST_REPORT.md.
#   1. parse check of every script
#   2. unit tests
#   3. acceptance phase 1 and phase 2 (two separate OS processes),
#      executed inside a network namespace with NO network (unshare -rn)
#      when available, to prove the game runs offline (VS-022)
#   4. static scan for networking APIs
#   5. headless CPU benchmark (+ rendered benchmark if xvfb-run exists)
#   6. tools/make_test_report.py -> TEST_REPORT.md
set -u
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
OUT=systems/tests/output
mkdir -p "$OUT"

echo "== parse check"; tools/check.sh || exit 1

echo "== unit tests"
timeout 300 $GODOT --headless res://systems/tests/test_runner.tscn > "$OUT/unit.log" 2>&1
echo "unit exit: $?" | tee -a "$OUT/unit.log"

NET=""
if unshare -rn true 2>/dev/null; then NET="unshare -rn"; fi
echo "== network isolation: '${NET:-none}'"
{
  echo "{"
  echo "  \"isolation\": \"${NET:-none}\","
  if [ -n "$NET" ]; then
    ifaces=$($NET cat /proc/net/dev | tail -n +3 | awk -F: '{gsub(/ /,"",$1); print $1}' | tr '\n' ' ')
    dns=$($NET python3 -c "import socket
try:
  socket.create_connection(('github.com',443),3); print('reachable')
except Exception as e: print('unreachable: '+type(e).__name__)" 2>&1)
    echo "  \"interfaces\": \"$ifaces\","
    echo "  \"internet_probe\": \"$dns\","
  fi
  echo "  \"date\": \"$(date -Iseconds)\""
  echo "}"
} > "$OUT/offline_evidence.json"
cat "$OUT/offline_evidence.json"

echo "== acceptance phase 1"
timeout 1800 $NET $GODOT --headless --fixed-fps 60 res://systems/tests/acceptance/acceptance_bot.tscn -- --phase=1 > "$OUT/phase1.log" 2>&1
echo "phase1 exit: $?" | tee -a "$OUT/phase1.log"
echo "== acceptance phase 2 (relaunch)"
timeout 1800 $NET $GODOT --headless --fixed-fps 60 res://systems/tests/acceptance/acceptance_bot.tscn -- --phase=2 > "$OUT/phase2.log" 2>&1
echo "phase2 exit: $?" | tee -a "$OUT/phase2.log"

echo "== class smoke test (all heroines)"
timeout 600 $NET $GODOT --headless --fixed-fps 60 res://systems/tests/class_smoke.tscn > "$OUT/class_smoke.log" 2>&1
echo "class smoke exit: $?"

echo "== static network API scan"
grep -rnE "HTTPRequest|HTTPClient|StreamPeerTCP|StreamPeerTLS|PacketPeerUDP|WebSocket|ENetMultiplayer|MultiplayerPeer|TCPServer|UDPServer|OS\.shell_open|JavaScriptBridge" \
  --include=*.gd game systems | grep -v "systems/tests/" > "$OUT/network_scan.txt"
echo "matches: $(wc -l < "$OUT/network_scan.txt")"

echo "== benchmark"
timeout 600 $GODOT --headless --fixed-fps 60 res://systems/tests/benchmark.tscn -- --out=perf_headless.json > "$OUT/bench_headless.log" 2>&1
if command -v xvfb-run >/dev/null; then
  timeout 900 xvfb-run -a -s "-screen 0 1600x900x24" $GODOT --rendering-driver opengl3 --resolution 1600x900 res://systems/tests/benchmark.tscn -- --out=perf_rendered.json > "$OUT/bench_rendered.log" 2>&1
fi

# Optional: run the same acceptance phases with the exported WINDOWS build
# under Wine (needs wine + Godot 4.3 export templates).
if command -v wine >/dev/null && [ -f "$HOME/.local/share/godot/export_templates/4.3.stable/windows_release_x86_64.exe" ]; then
  echo "== Windows build under Wine"
  mkdir -p builds/windows_test
  timeout 900 $GODOT --headless --export-release "Windows Desktop (with tests)" builds/windows_test/Gloamreach_test.exe > "$OUT/export_win_test.log" 2>&1
  export WINEDEBUG=-all WINEPREFIX=${WINEPREFIX:-/tmp/gloamreach_wineprefix}
  UD="$WINEPREFIX/drive_c/users/$(whoami)/AppData/Roaming/Godot/app_userdata/Gloamreach"
  rm -rf "$UD"
  for ph in 1 2; do
    timeout 2400 $NET wine builds/windows_test/Gloamreach_test.exe --headless --fixed-fps 60 res://systems/tests/acceptance/acceptance_bot.tscn -- --phase=$ph > "$OUT/wine_phase$ph.log" 2>&1
    echo "wine phase$ph exit: $?" | tee -a "$OUT/wine_phase$ph.log"
    cp "$UD/test_output/acceptance_phase$ph.json" "$OUT/wine_acceptance_phase$ph.json" 2>/dev/null
  done
fi

# Real OS-level mouse/keyboard input on a real game window (Xvfb + xdotool)
if command -v xvfb-run >/dev/null && command -v xdotool >/dev/null; then
  echo "== real input test (xdotool on the game window)"
  timeout 900 python3 tools/real_input_test.py > "$OUT/real_input.log" 2>&1
  echo "real input exit: $?" | tee -a "$OUT/real_input.log"
  if command -v wine >/dev/null && [ -f builds/windows_test/Gloamreach_test.exe ]; then
    cp "$OUT/real_input.json" "$OUT/real_input_linux.json"
    timeout 900 python3 tools/real_input_test.py --exe builds/windows_test/Gloamreach_test.exe --wine > "$OUT/real_input_wine.log" 2>&1
    echo "real input (wine) exit: $?"
    cp "$OUT/real_input.json" "$OUT/real_input_wine.json"
    cp "$OUT/real_input_linux.json" "$OUT/real_input.json"
  fi
fi

echo "== report"
python3 tools/make_test_report.py
