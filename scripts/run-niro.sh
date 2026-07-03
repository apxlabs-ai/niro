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
  NIRO_GOAL          default goal when --goal is not set
  NIRO_MODEL         default model when --model is not set
  NIRO_SUMMARY_FILE  if set, also save the run summary to this path (it is
                     still printed as usual). CI uses this to show the summary
                     on the workflow run page.
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

# Hand the coding agent the niro config directory explicitly, every run — it is
# NIRO_CONFIG_DIR when set, else `niro/` at the project root. Resolve it to an
# absolute path here: start_pentest requires an absolute niro_config_dir, and the
# agent shouldn't have to convert a relative one (nor discover the dir at all).
# Fail fast with a clear message if it's missing or unscaffolded, rather than
# launching the agent only for it to stall on a bad config dir.
config_dir="${NIRO_CONFIG_DIR:-niro}"
config_dir_abs=$(cd "$config_dir" 2>/dev/null && pwd) \
  || die "niro config dir '$config_dir' not found; set NIRO_CONFIG_DIR or run 'niro init'"
[ -f "$config_dir_abs/niro.yaml" ] \
  || die "niro config dir '$config_dir_abs' has no niro.yaml; run 'niro init' to scaffold it"
goal="$goal

Use the niro config directory at $config_dir_abs — this exact absolute path. Do not discover or substitute another."

run_agent() {
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
}

# The agent prints its final run summary to stdout. Capture that to
# NIRO_SUMMARY_FILE (if set) while still streaming it to the log, so CI can
# render it as a job summary. The capture is scoped to the agent command, so
# run-niro's own diagnostics (all on stderr) can never leak into the summary.
summary_file="${NIRO_SUMMARY_FILE:-/dev/null}"

# Best-effort: ensure the summary directory exists so tee can write it.
mkdir -p "$(dirname "$summary_file")" 2>/dev/null || true

# PIPESTATUS[0] is the agent's own exit code — propagate that, not tee's, so
# writing the summary can never fail an otherwise-successful run (nor mask a
# failed one).
set +e
run_agent | tee "$summary_file"
rc=${PIPESTATUS[0]}

# If Niro changed the config dir this run, surface the committable files so the
# developer can persist Niro's growing understanding of their app — committing
# it makes future runs cheaper/faster/sharper instead of relearning. Uses git,
# not the agent: gitignore-aware and filenames-only (never a secret value).
# credentials.yaml, fixtures.yaml, findings/, and harness/run/ are excluded —
# secrets / regenerated each run / run output (findings are already carried by
# the fix PRs) / transient run state, none of which is the durable harness
# knowledge worth committing. niro init gitignores these for the default niro/
# dir; the explicit excludes below also cover a custom config dir, where they
# may not be gitignored. Best-effort — errexit stays off so it can't touch the
# run's exit code; skipped outside a git repo. Generic (no CI/artifact
# assumptions); appended to the summary + echoed to stderr so it shows on a
# local run too. config_dir was resolved and validated above.
changed=$(git status --porcelain --untracked-files=all -- "$config_dir" \
  ":(exclude)$config_dir/credentials.yaml" ":(exclude)$config_dir/fixtures.yaml" \
  ":(exclude)$config_dir/findings" ":(exclude)$config_dir/harness/run" 2>/dev/null)
if [ -n "$changed" ]; then
  printf '\n💡 **Niro enhanced its knowledge of your app this run**, saved in `%s`. Review and commit it: this **compounds** — each run builds on the last, so keeping it makes future pentests cheaper, faster, and sharper instead of relearning from scratch.\n\n```\n%s\n```\n' \
    "$config_dir" "$changed" | tee -a "$summary_file" >&2
fi

set -e
exit "$rc"
