#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
export XDG_CONFIG_HOME="${AUCTION_TEST_CONFIG_HOME:-/tmp/auctionmaster-config}"
export XDG_CACHE_HOME="${AUCTION_TEST_CACHE_HOME:-/tmp/auctionmaster-cache}"
export XDG_DATA_HOME="${AUCTION_TEST_DATA_HOME:-/tmp/auctionmaster-data}"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
run_step() {
  local log
  log="$(mktemp)"
  if ! "$GODOT" "$@" 2>&1 | tee "$log"; then
    rm -f "$log"
    return 1
  fi
  if grep -Eq '(^ERROR:|SCRIPT ERROR:|Parse Error:)' "$log"; then
    echo "Godot reported a runtime/import error."
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
}
run_step --headless --editor --import --quit
for test in model_tests qa_rules ui_flow_tests qa_inventory_privacy qa_inventory_grid; do
  run_step --headless --script "res://tests/${test}.gd"
done
run_step --headless --quit-after 20
