#!/usr/bin/env bash
#
# run-niro - launch a coding agent for one headless Niro run.
#
# The caller provides an initialized repo, a reachable container runtime, and an
# authenticated coding-agent CLI. This wrapper validates only local executables
# and lets each agent own its auth modes and errors.
#
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run-niro <claude|codex|copilot> [--goal TEXT] [--model NAME]
  run-niro --agent <claude|codex|copilot> [--goal TEXT] [--model NAME]

Launch the chosen coding agent headless for one Niro run.

Options:
  --agent NAME    claude, codex, or copilot
  --goal TEXT     goal for Niro to accomplish
  --model NAME    model to pass through to the agent CLI
  -h, --help      show this help

Env:
  NIRO_GOAL       default goal when --goal is not set
  NIRO_MODEL      default model when --model is not set
EOF
}

die() {
  echo "run-niro: $*" >&2
  exit 2
}

need_value() {
  local flag="$1"
  local value="${2:-}"
  [ -n "$value" ] || die "$flag requires a value"
}

agent=""
goal="${NIRO_GOAL:-}"
model="${NIRO_MODEL:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --agent)
      need_value "$1" "${2:-}"
      agent="$2"
      shift 2
      ;;
    --goal)
      need_value "$1" "${2:-}"
      goal="$2"
      shift 2
      ;;
    --model)
      need_value "$1" "${2:-}"
      model="$2"
      shift 2
      ;;
    claude|codex|copilot)
      [ -z "$agent" ] || die "agent specified more than once"
      agent="$1"
      shift
      ;;
    --*)
      die "unknown option '$1'"
      ;;
    *)
      die "unknown argument '$1'"
      ;;
  esac
done

case "$agent" in
  claude|codex|copilot) ;;
  "") die "missing agent; expected claude, codex, or copilot" ;;
  *) die "unknown agent '$agent'; expected claude, codex, or copilot" ;;
esac

command -v niro >/dev/null 2>&1 || die "niro not found on PATH"
command -v "$agent" >/dev/null 2>&1 || die "$agent not found on PATH"

# Claude Code refuses --dangerously-skip-permissions under root unless
# IS_SANDBOX is set. Most customers run on a user account; this keeps root-based
# CI/container jobs working without changing an explicit caller setting.
if [ "$(id -u)" = "0" ] && [ -z "${IS_SANDBOX:-}" ]; then
  export IS_SANDBOX=1
fi

# Declare non-interactive operation. start_pentest is async: niro long-polls a
# sentinel via `niro wait`. Interactively, the agent backgrounds that wait and
# its harness re-wakes it on completion — but under `claude --print` a
# backgrounded shell is killed ~5s after the turn ends, cancelling the wait and
# tearing down the pentest. NIRO_HEADLESS=1 tells niro to instruct the agent to
# run the wait in the FOREGROUND instead, so the run stays alive until findings
# land. This is the one thing only the harness knows (the agent can't tell it's
# in --print mode), so the harness declares it explicitly.
export NIRO_HEADLESS=1

# Keep Claude's Bash-tool timeout above the foreground wait window. `niro wait`
# is bounded at --max-wait=8m; Claude's Bash tool defaults to 2m (ceiling 10m),
# which would kill the wait early. Raise the default and ceiling to 9m so the
# 8m window fits with margin. (Codex ignores these; they are Claude-specific.)
export BASH_DEFAULT_TIMEOUT_MS=540000
export BASH_MAX_TIMEOUT_MS=540000

# Optional model pin. --model selects the LLM the coding agent drives; every
# supported CLI accepts --model. Unset => the CLI's own default. Mirrors
# --goal/NIRO_GOAL: one wrapper knob, mapped here to each agent's flag.
model_args=()
if [[ -n "$model" ]]; then
  model_args=(--model "$model")
fi

if [[ -z "$goal" ]]; then
  goal="$(cat <<'GOAL'
Pentest this application and create PRs.

You are running in autonomous CI mode. There is no human available
to answer questions, so make reasonable assumptions and proceed end
to end.
GOAL
)"
fi

case "$agent" in
  claude)
    # No --bare: it bypasses the OAuth-token auth path, so subscription auth
    # (CLAUDE_CODE_OAUTH_TOKEN) fails with "Not logged in". --print alone gives
    # the non-interactive output CI needs.
    claude --print --dangerously-skip-permissions ${model_args[@]+"${model_args[@]}"} "$goal"
    ;;
  codex)
    codex exec \
      --dangerously-bypass-approvals-and-sandbox \
      ${model_args[@]+"${model_args[@]}"} \
      "$goal"
    ;;
  copilot)
    GITHUB_COPILOT_PROMPT_MODE_WORKSPACE_MCP=true \
      copilot -p "$goal" --yolo ${model_args[@]+"${model_args[@]}"}
    ;;
  *)
    echo "run-niro: internal error: unvalidated agent '${agent}'" >&2
    exit 1
    ;;
esac
