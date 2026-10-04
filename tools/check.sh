#!/bin/bash
# Parse every script headless and list unique script errors.
cd "$(dirname "$0")/.."
timeout 300 godot --headless --editor --quit 2>&1 | grep -A1 -E "SCRIPT ERROR|ERROR:" | grep -v "^--$" | paste - - | sort -u | grep -v "Compile Error: " | sed 's/\s\+/ /g'
