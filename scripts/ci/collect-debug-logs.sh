#!/usr/bin/env bash
#
# Purpose: collect Niro and coding-agent debug logs for CI artifact upload.
# Inputs:
#   $1               optional output directory; defaults to niro-debug-artifacts
#   XDG_CACHE_HOME   optional cache root; defaults to $HOME/.cache
#   HOME             used to locate agent log directories
# Output: creates a debug-log directory tree when logs are available.
# Exit code: 0 on success, including partial/no logs; non-zero for setup failures.
#
set -euo pipefail

out="${1:-niro-debug-artifacts}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
niro_log_dir="$cache_dir/niro/logs"

mkdir -p "$out"

# Purpose: copy one log directory into the debug bundle.
# Inputs: source directory, destination directory.
# Output: copies files except transient *.lock files; skips missing sources.
# Exit code: 0 on success or missing source; tar/mkdir failures may return non-zero.
copy_dir() {
  local src="$1"
  local dst="$2"

  [[ -d "$src" ]] || return 0   # source not present on this machine — skip
  mkdir -p "$dst"
  # Intentionally skip *.lock files. They are transient flock sentinels —
  # useless for debugging — and the agent container leaves them root-owned, so
  # copying them would hit "Permission denied". tar --exclude never reads them
  # and preserves attrs like cp -a. The bundle's own directory tree is the
  # record of what was collected, so there's no separate manifest to keep.
  tar --exclude='*.lock' -C "$src" -cf - . 2>/dev/null | tar -C "$dst" -xf - 2>/dev/null
}

# Collect every source best-effort and INDEPENDENTLY: if one source fails for
# any reason, keep going to the next — a partial bundle beats aborting on the
# first. Disabling errexit for this section is defense in depth: it covers an
# unguarded mkdir, the tar pipe, or any failure a future edit adds.
#
# Destinations keep each source's own subdir under logs/<tool>/ so the bundle
# mirrors where each came from (logs/claude/projects, logs/codex/sessions, ...).
# niro is the exception: its source subdir is literally "logs", so it collapses
# to logs/niro rather than the redundant logs/niro/logs.
set +e
copy_dir "$niro_log_dir" "$out/logs/niro"
copy_dir "$HOME/.claude/projects" "$out/logs/claude/projects"
copy_dir "$HOME/.codex/sessions" "$out/logs/codex/sessions"
copy_dir "$HOME/.copilot/session-state" "$out/logs/copilot/session-state"
set -e
