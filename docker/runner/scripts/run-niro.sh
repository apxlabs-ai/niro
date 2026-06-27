#!/usr/bin/env bash
set -euo pipefail

agent="${1:-}"

prompt="${NIRO_PROMPT:-$(cat <<'PROMPT'
Pentest this application and create PRs.

You are running in autonomous CI mode. There is no human available
to answer questions, so make reasonable assumptions and proceed end
to end.
PROMPT
)}"

case "$agent" in
  claude)
    claude --bare --print --dangerously-skip-permissions "$prompt"
    ;;
  codex)
    codex exec \
      --dangerously-bypass-approvals-and-sandbox \
      "$prompt"
    ;;
  copilot)
    gh copilot -- -p "$prompt" --yolo
    ;;
  *)
    echo "Unsupported agent=${agent}. Expected claude, codex, or copilot." >&2
    exit 1
    ;;
esac
