#!/usr/bin/env bash
set -euo pipefail

out="${1:-niro-debug-artifacts}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
niro_log_dir="$cache_dir/niro/logs"
niro_task_dir="$cache_dir/niro/tasks"
manifest="$out/MANIFEST.txt"

mkdir -p "$out"
: > "$manifest"

copy_dir() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [[ -d "$src" ]]; then
    mkdir -p "$dst"
    cp -a "$src"/. "$dst"/
    printf 'copied\t%s\t%s\n' "$label" "$src" >> "$manifest"
  else
    printf 'missing\t%s\t%s\n' "$label" "$src" >> "$manifest"
  fi
}

copy_dir "$niro_log_dir" "$out/niro/logs" "niro logs"
copy_dir "$niro_task_dir" "$out/niro/tasks" "niro tasks"
copy_dir "/niro/logs" "$out/niro/container-logs" "niro container logs"
copy_dir "$HOME/.claude/projects" "$out/claude/projects" "claude projects"
copy_dir "$HOME/.codex/sessions" "$out/codex/sessions" "codex sessions"
copy_dir "$HOME/.copilot/session-state" "$out/copilot/session-state" "copilot session state"
copy_dir "$HOME/.copilot/logs" "$out/copilot/logs" "copilot logs"
