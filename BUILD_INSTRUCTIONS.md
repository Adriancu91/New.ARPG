# Build Instructions

## Requirements

- **Godot 4.3-stable** (standard, not .NET): <https://godotengine.org/download/archive/4.3-stable/>
- For exporting: the matching **export templates** (Editor → *Manage Export Templates* → Download, or the `Godot_v4.3-stable_export_templates.tpz` file).
- Optional for the test suite: `python3` (report generator), `xvfb-run` (rendered benchmark/screenshots on Linux), `wine` (running the Windows build on Linux).

No other dependencies, no accounts, no network access are required. The game never connects to the internet.

## Run from source

```bash
git clone https://github.com/Adriancu91/new.arpg.git
cd new.arpg
godot --path .            # or open project.godot in the Godot editor and press F5
```

The first launch imports the project (a few seconds). Saves go to:

- Windows: `%APPDATA%\Godot\app_userdata\Gloamreach\saves\`
- Linux: `~/.local/share/godot/app_userdata/Gloamreach/saves/`

## Export a Windows build

In the editor: *Project → Export → Windows Desktop → Export Project*. From the command line:

```bash
godot --headless --export-release "Windows Desktop" builds/windows/Gloamreach.exe
```

The preset (`export_presets.cfg`) embeds the game data in the `.exe` (single file, ~85 MB), targets x86_64 and excludes tests and tools. A Linux preset is included as well:

```bash
godot --headless --export-release "Linux" builds/linux/Gloamreach.x86_64
```

`builds/` is git-ignored; attach exported binaries to a GitHub release instead of committing them.

## Tests

```bash
tools/check.sh                                            # every script must parse
godot --headless res://systems/tests/test_runner.tscn     # unit tests (exit code 0 = all pass)
godot --headless --fixed-fps 60 res://systems/tests/acceptance/acceptance_bot.tscn -- --phase=1   # playthrough + save + quit
godot --headless --fixed-fps 60 res://systems/tests/acceptance/acceptance_bot.tscn -- --phase=2   # relaunch + load + continue
godot --headless --fixed-fps 60 res://systems/tests/class_smoke.tscn                              # all heroines' skills
godot --headless --fixed-fps 60 res://systems/tests/benchmark.tscn -- --out=perf_headless.json    # CPU frame cost, memory
tools/run_acceptance.sh                                   # all of the above (offline via `unshare -rn` when available) + TEST_REPORT.md
```

On a Windows machine with a GPU, measure real performance (VS-025) with:

```bash
Godot_v4.3-stable_win64.exe --path . res://systems/tests/benchmark.tscn -- --out=perf_windows.json
```

The result lands in `systems/tests/output/perf_windows.json`.

Visual check (renders screenshots of menus, zones, UI and the boss):

```bash
godot res://systems/tests/screenshot_tour.tscn                       # with a display
xvfb-run -a godot --rendering-driver opengl3 res://systems/tests/screenshot_tour.tscn   # headless Linux
```

## Renderer

The project uses **Forward+** (best lighting, SSAO, glow, fog) on Windows/Linux GPUs. It also runs on the Compatibility (OpenGL 3.3) renderer: `--rendering-driver opengl3`. SSAO is skipped there automatically.
