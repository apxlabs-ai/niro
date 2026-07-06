#!/usr/bin/env bash
#
# niro-ci - CI orchestration wrapper for Niro find/fix workflows.
#
# This is the stable customer-facing CI entrypoint. Keep workflow YAML thin and
# put install/init/run/summary/artifact preparation here.
#
set -euo pipefail

NIRO_SCRIPT_NAME="niro-ci"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$script_dir/../scripts/ci/lib.sh" ]; then
  ci_script_dir="$(cd "$script_dir/../scripts/ci" && pwd)"
else
  ci_script_dir="$script_dir"
fi
# shellcheck source=public/scripts/ci/lib.sh
. "$ci_script_dir/lib.sh"
# shellcheck source=public/scripts/ci/providers/generic.sh
. "$ci_script_dir/providers/generic.sh"
if [ -x "$ci_script_dir/collect-knowledge" ]; then
  collect_knowledge_script="$ci_script_dir/collect-knowledge"
else
  collect_knowledge_script="$ci_script_dir/collect-knowledge.sh"
fi
if [ -x "$ci_script_dir/collect-debug-logs" ]; then
  collect_debug_script="$ci_script_dir/collect-debug-logs"
else
  collect_debug_script="$ci_script_dir/collect-debug-logs.sh"
fi

usage() {
  cat <<'EOF'
Usage:
  niro-ci find
  niro-ci fix

Environment:
  NIRO_AGENT                         claude, codex, or copilot (default: claude)
  NIRO_CONFIG_DIR                    config directory under repo root (default: niro)
  NIRO_GOAL                          required goal for Niro
  NIRO_MODEL                         optional model override for selected agent
  NIRO_PROGRESS_FILE                 optional JSONL progress stream path
  NIRO_CI_ARTIFACT_INCLUDE_FINDINGS  include findings in niro-knowledge.tar (default: true)
  NIRO_CI_ARTIFACT_UPLOAD_DEBUG_LOGS collect debug logs for upload (default: false)
  CODEX_AUTH_JSON_B64                optional base64-encoded Codex auth.json for NIRO_AGENT=codex
EOF
}

# Purpose: configure git for CI-owned reads and, in fix mode, commits.
# Inputs: mode (find|fix), workspace path.
# Output: updates git config; no stdout.
# Exit code: returns 0 on success; git failures in fix mode propagate.
ensure_git_config() {
  local mode="$1"
  local workspace="$2"

  git config --global --add safe.directory "$workspace" 2>/dev/null || true
  if [ "$mode" = "fix" ]; then
    ci_configure_git_author
  fi
}

# Purpose: ensure the selected Niro config directory exists and is initialized.
# Inputs: workspace path, agent name, config directory path relative to workspace.
# Output: runs `niro init` for the selected config dir and logs status to stderr.
# Exit code: returns 0 on success; init or validation failures propagate.
ensure_config_dir() {
  local workspace="$1"
  local agent="$2"
  local config_dir="$3"

  if [ -f "$workspace/$config_dir/niro.yaml" ]; then
    niro_log "using existing $config_dir"
  else
    niro_log "initializing $config_dir"
  fi

  niro init "$workspace" --agent "$agent" --config-dir "$config_dir" --quiet
  [ -f "$workspace/$config_dir/niro.yaml" ] \
    || niro_die "niro init did not create $config_dir/niro.yaml"
}

# Purpose: restore a base64-encoded Codex auth.json for CI jobs that cannot run
# an interactive Codex login. The secret is removed from the environment before
# the agent starts so child processes do not inherit the raw base64 blob.
# Inputs: CODEX_AUTH_JSON_B64, CODEX_HOME, HOME, selected agent.
# Output: writes ${CODEX_HOME:-$HOME/.codex}/auth.json when configured.
# Exit code: returns 0 on success/no-op; decode or filesystem failures exit.
restore_codex_auth_json() {
  local auth_dir auth_file

  if [ "$agent" != "codex" ]; then
    unset CODEX_AUTH_JSON_B64
    return 0
  fi
  if [ -z "${CODEX_AUTH_JSON_B64:-}" ]; then
    return 0
  fi

  if [ -n "${CODEX_HOME:-}" ]; then
    auth_dir="$CODEX_HOME"
  elif [ -n "${HOME:-}" ]; then
    auth_dir="$HOME/.codex"
  else
    niro_die "CODEX_AUTH_JSON_B64 is set but neither CODEX_HOME nor HOME is available"
  fi
  auth_file="$auth_dir/auth.json"

  mkdir -p "$auth_dir" \
    || niro_die "failed to create Codex auth directory '$auth_dir'"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import base64, os, sys; sys.stdout.buffer.write(base64.b64decode(os.environ["CODEX_AUTH_JSON_B64"]))' > "$auth_file" \
      || { rm -f "$auth_file"; unset CODEX_AUTH_JSON_B64; niro_die "failed to decode CODEX_AUTH_JSON_B64"; }
  else
    printf '%s' "$CODEX_AUTH_JSON_B64" | base64 -d > "$auth_file" \
      || { rm -f "$auth_file"; unset CODEX_AUTH_JSON_B64; niro_die "failed to decode CODEX_AUTH_JSON_B64"; }
  fi
  chmod 600 "$auth_file" \
    || niro_die "failed to chmod Codex auth file '$auth_file'"
  unset CODEX_AUTH_JSON_B64
  niro_log "restored Codex auth.json from CODEX_AUTH_JSON_B64"
}

# Purpose: publish the captured Niro summary through the current CI provider.
# Inputs: summary file path.
# Output: appends to the provider job summary when available.
# Exit code: returns 0 unless the append fails.
publish_summary() {
  local summary_file="$1"

  ci_append_summary "$summary_file"
}

# Purpose: create a unique default Niro progress file for this wrapper run.
# Inputs: none; uses ci_temp_dir.
# Output: prints the created progress file path.
# Exit code: returns 0 on success; exits 2 when the file cannot be created.
make_default_progress_file() {
  local tmp_dir path

  tmp_dir="$(ci_temp_dir)"
  mkdir -p "$tmp_dir" 2>/dev/null || true
  path="$(mktemp "$tmp_dir/niro-progress.XXXXXX")" \
    || niro_die "failed to create progress file in $tmp_dir"
  printf '%s\n' "$path"
}

# Purpose: stream Niro progress JSONL messages to CI stdout.
# Inputs: progress file path.
# Output: prints each event's timestamp and message as it is appended.
# Exit code: starts a background tailer; returns 0 unless setup fails.
start_progress_stream() {
  local progress_file="$1"

  mkdir -p "$(dirname "$progress_file")" 2>/dev/null || true
  touch "$progress_file"

  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json
import os
import signal
import sys
import time

path = sys.argv[1]
stopping = False

def request_stop(_signum, _frame):
    global stopping
    stopping = True

def format_time(ts):
    if ts.endswith("Z"):
        ts = ts[:-1]
    if "T" in ts:
        ts = ts.rsplit("T", 1)[-1]
    return ts or time.strftime("%H:%M:%S", time.gmtime())

def print_event(line):
    try:
        event = json.loads(line)
    except Exception:
        event = {}
    msg = event.get("message", "")
    if msg:
        ts = format_time(event.get("ts", ""))
        print(f"[{ts}] {msg}", flush=True)

signal.signal(signal.SIGINT, request_stop)
signal.signal(signal.SIGTERM, request_stop)

with open(path, "r", encoding="utf-8") as f:
    f.seek(0, os.SEEK_END)
    while True:
        line = f.readline()
        if not line:
            if stopping:
                break
            time.sleep(0.2)
            continue
        print_event(line)
' "$progress_file" &
  else
    tail -n 0 -f "$progress_file" | sed -u -n 's/^.*"ts":"[^T]*T\([^Z"]*\)Z","message":"\([^"]*\)".*$/[\1] \2/p' &
  fi
  progress_stream_pid=$!
}

# Purpose: stop the background progress stream.
# Inputs: progress_stream_pid optional global.
# Output: none.
# Exit code: returns 0.
stop_progress_stream() {
  if [ -n "${progress_stream_pid:-}" ]; then
    # Let the streamer consume events written immediately before run_agent exited.
    sleep 1
    kill "$progress_stream_pid" 2>/dev/null || true
    wait "$progress_stream_pid" 2>/dev/null || true
    progress_stream_pid=""
  fi
}

# Purpose: run the selected coding agent with the prepared Niro goal.
# Inputs: agent name, goal text, model_args array, and NIRO_CONFIG_DIR.
# Output: streams agent stdout through tee into NIRO_SUMMARY_FILE. Codex stderr
# is captured and only tailed when Codex fails, to keep CI logs readable.
# Exit code: returns the selected agent command's exit code.
run_agent() {
  local config_dir_abs mode_instruction ci_context settings_file settings_args
  local codex_stderr_file rc

  niro_need_cmd "$agent"

  # Claude Code refuses --dangerously-skip-permissions under root unless
  # IS_SANDBOX is set. Most customers run on a user account; this keeps
  # root-based CI/container jobs working without changing explicit caller state.
  if [ "$(id -u)" = "0" ] && [ -z "${IS_SANDBOX:-}" ]; then
    export IS_SANDBOX=1
  fi

  # `niro wait` is bounded at --max-wait=8m; Claude's Bash tool defaults below
  # that. Raise Claude's default and ceiling so foreground waits can finish.
  export NIRO_HEADLESS=1
  export BASH_DEFAULT_TIMEOUT_MS=540000
  export BASH_MAX_TIMEOUT_MS=540000

  config_dir_abs=$(cd "$NIRO_CONFIG_DIR" 2>/dev/null && pwd) \
    || niro_die "niro config dir '$NIRO_CONFIG_DIR' not found"
  [ -f "$config_dir_abs/niro.yaml" ] \
    || niro_die "niro config dir '$config_dir_abs' has no niro.yaml"

  case "$mode" in
    find)
      mode_instruction="This is a Niro find run: pentest and report findings only. Do not create branches, commits, or pull requests."
      ;;
    fix)
      mode_instruction="This is a Niro fix run: pentest and create review-ready fix pull requests for confirmed findings."
      ;;
    *)
      niro_die "internal error: unvalidated mode '$mode'"
      ;;
  esac

  ci_context="$(ci_run_context)"

  goal="$goal

$mode_instruction

$ci_context

Use the niro config directory at $config_dir_abs — this exact absolute path. Do not discover or substitute another."

  mkdir -p "$(dirname "$summary_file")" 2>/dev/null || true
  codex_stderr_file=""
  if [ "$agent" = "codex" ]; then
    codex_stderr_file="$(ci_temp_dir)/codex-stderr.log"
    : > "$codex_stderr_file" \
      || niro_die "failed to create Codex stderr log '$codex_stderr_file'"
  fi

  case "$agent" in
    claude)
      # Claude Code --print has its own background-task wait ceiling. CI runs
      # are bounded by the job/Niro deadlines, so do not let Claude's 600s
      # default kill delegated work such as slow harness builds.
      export CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0
      # CI-only settings: a PreToolUse hook that blocks background bash so the
      # foreground stream keeps the process (and the MCP-hosted pentest) alive
      # to completion. Merges with the project .claude/settings.json (its
      # PostToolUse hook still fires). Guarded for older installs missing it.
      settings_file="$ci_script_dir/providers/claude.settings.json"
      settings_args=()
      [ -f "$settings_file" ] && settings_args=(--settings "$settings_file")
      claude --print --dangerously-skip-permissions ${settings_args[@]+"${settings_args[@]}"} ${model_args[@]+"${model_args[@]}"} "$goal"
      ;;
    codex)
      codex exec \
        --dangerously-bypass-approvals-and-sandbox \
        ${model_args[@]+"${model_args[@]}"} \
        "$goal" \
        2>"$codex_stderr_file"
      ;;
    copilot)
      GITHUB_COPILOT_PROMPT_MODE_WORKSPACE_MCP=true \
        copilot -p "$goal" --yolo ${model_args[@]+"${model_args[@]}"}
      ;;
    *)
      niro_die "internal error: unvalidated agent '$agent'"
      ;;
  esac | tee "$summary_file"

  rc="${PIPESTATUS[0]}"
  if [ "$agent" = "codex" ]; then
    if [ "$rc" -ne 0 ] && [ -s "$codex_stderr_file" ]; then
      {
        printf '::group::Codex stderr tail\n'
        tail -n 120 "$codex_stderr_file" || true
        printf '::endgroup::\n'
      } >&2
    fi
    rm -f "$codex_stderr_file" 2>/dev/null || true
  fi

  return "$rc"
}

# Purpose: prepare the Niro knowledge tarball for CI artifact upload.
# Inputs: none; reads NIRO_CONFIG_DIR and NIRO_CI_ARTIFACT_INCLUDE_FINDINGS.
# Output: creates niro-knowledge.tar when there is knowledge to upload.
# Exit code: returns 0 on success/no-op; exits 2 when helper is missing;
# collector failures propagate.
collect_knowledge() {
  if [ ! -x "$collect_knowledge_script" ]; then
    niro_die "collect-knowledge not found next to niro-ci"
  fi

  "$collect_knowledge_script" niro-knowledge.tar
}

# Purpose: prepare debug logs for CI artifact upload.
# Inputs: none.
# Output: creates niro-debug-artifacts/ when logs are available.
# Exit code: returns 0 on success; exits 2 when helper is missing; collector
# failures propagate.
collect_debug_logs() {
  if [ ! -x "$collect_debug_script" ]; then
    niro_die "collect-debug-logs not found next to niro-ci"
  fi

  "$collect_debug_script" niro-debug-artifacts
}

mode="${1:-}"
case "$mode" in
  -h|--help)
    usage
    exit 0
    ;;
  find|fix)
    shift
    ;;
  "")
    usage >&2
    exit 2
    ;;
  *)
    niro_die "unknown command '$mode'; expected find or fix"
    ;;
esac
[ $# -eq 0 ] || niro_die "unexpected arguments: $*"

niro_need_cmd niro
niro_need_cmd git

agent="${NIRO_AGENT:-claude}"
config_dir="${NIRO_CONFIG_DIR:-niro}"
goal="${NIRO_GOAL:-}"
model="${NIRO_MODEL:-}"
upload_debug_logs="${NIRO_CI_ARTIFACT_UPLOAD_DEBUG_LOGS:-false}"
provider="$(ci_detect_provider)"
if [ "$provider" = "github-actions" ]; then
  # shellcheck source=public/scripts/ci/providers/github-actions.sh
  . "$ci_script_dir/providers/github-actions.sh"
fi
workspace="$(ci_workspace)"
summary_file="$(ci_temp_dir)/niro-summary.md"
progress_stream_pid=""
trap stop_progress_stream EXIT

case "$agent" in
  claude|codex|copilot) ;;
  *) niro_die "unknown NIRO_AGENT '$agent'; expected claude, codex, or copilot" ;;
esac
[ -n "$goal" ] || niro_die "NIRO_GOAL is required"

ci_require_fix_auth "$mode"

cd "$workspace"

if [ -z "${COPILOT_PROVIDER_API_KEY:-}" ] && [ -n "${OPEN_ROUTER_API_KEY:-}" ]; then
  export COPILOT_PROVIDER_API_KEY="$OPEN_ROUTER_API_KEY"
fi

niro_install_agent "$agent"
ensure_git_config "$mode" "$workspace"
ensure_config_dir "$workspace" "$agent" "$config_dir"
restore_codex_auth_json

export NIRO_CONFIG_DIR="$config_dir"
export NIRO_GOAL="$goal"
export NIRO_SUMMARY_FILE="$summary_file"
if [ -z "${NIRO_PROGRESS_FILE:-}" ]; then
  NIRO_PROGRESS_FILE="$(make_default_progress_file)"
  export NIRO_PROGRESS_FILE
fi

model_args=()
if [ -n "$model" ]; then
  model_args=(--model "$model")
fi

start_progress_stream "$NIRO_PROGRESS_FILE"
set +e
run_agent
rc=$?
set -e
stop_progress_stream

publish_summary "$summary_file"
collect_knowledge

if niro_bool_enabled "$upload_debug_logs"; then
  collect_debug_logs
else
  rm -rf niro-debug-artifacts 2>/dev/null || true
fi

ci_append_knowledge_note

exit "$rc"
