#!/bin/bash
# Parse every script headless; print unique script errors; exit 1 if any.
cd "$(dirname "$0")/.."
out=$(timeout 300 godot --headless --editor --quit 2>&1 | grep -A1 -E "SCRIPT ERROR|ERROR:" | grep -v "^--$" | paste - - | sort -u | grep -v "Compile Error: " | sed 's/\s\+/ /g')
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "All scripts parse OK"
