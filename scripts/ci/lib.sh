#!/usr/bin/env bash

# Purpose: print a fatal script error and stop execution.
# Inputs: error message arguments.
# Output: writes the formatted error to stderr.
# Exit code: exits with 2.
niro_die() {
  local program="${NIRO_SCRIPT_NAME:-niro}"
  echo "$program: $*" >&2
  exit 2
}

# Purpose: print a script status message.
# Inputs: message arguments.
# Output: writes the formatted message to stderr.
# Exit code: returns 0 unless stderr write fails.
niro_log() {
  local program="${NIRO_SCRIPT_NAME:-niro}"
  echo "$program: $*" >&2
}

# Purpose: test whether a string represents an enabled boolean.
# Inputs: boolean-like string.
# Output: none.
# Exit code: 0 for true/yes/on/1, 1 otherwise.
niro_bool_enabled() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

# Purpose: require an executable to exist on PATH.
# Inputs: command name.
# Output: fatal error to stderr when missing.
# Exit code: returns 0 when found; exits 2 when missing.
niro_need_cmd() {
  command -v "$1" >/dev/null 2>&1 || niro_die "$1 not found on PATH"
}

# Purpose: install the selected coding agent CLI when it is not already present.
# Inputs: agent name: claude, codex, or copilot.
# Output: install progress from npm and status messages to stderr.
# Exit code: returns 0 when available/installed; exits 2 for invalid input or
# missing npm; npm failure returns npm's exit code.
niro_install_agent() {
  local agent="$1"

  if command -v "$agent" >/dev/null 2>&1; then
    return 0
  fi

  niro_need_cmd npm
  case "$agent" in
    claude)
      niro_log "installing Claude Code"
      npm install -g @anthropic-ai/claude-code
      ;;
    codex)
      niro_log "installing Codex"
      npm install -g @openai/codex
      ;;
    copilot)
      niro_log "installing Copilot CLI"
      npm install -g @github/copilot
      ;;
    *)
      niro_die "unknown agent '$agent'; expected claude, codex, or copilot"
      ;;
  esac
}
