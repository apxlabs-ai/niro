#!/usr/bin/env bash

# Purpose: resolve the GitHub Actions workspace directory.
# Inputs: GITHUB_WORKSPACE optional environment variable.
# Output: prints the workspace path.
# Exit code: returns 0.
ci_workspace() {
  printf '%s\n' "${GITHUB_WORKSPACE:-$(pwd)}"
}

# Purpose: resolve the GitHub Actions temp directory.
# Inputs: RUNNER_TEMP optional environment variable.
# Output: prints a temp directory path.
# Exit code: returns 0.
ci_temp_dir() {
  printf '%s\n' "${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
}

# Purpose: append a markdown file to the GitHub Actions job summary.
# Inputs: summary file path.
# Output: appends to $GITHUB_STEP_SUMMARY when available.
# Exit code: returns 0 unless the append fails.
ci_append_summary() {
  local summary_file="$1"

  if [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ -s "$summary_file" ]; then
    cat "$summary_file" >> "$GITHUB_STEP_SUMMARY"
  fi
}

# Purpose: append the Niro knowledge artifact note to the GitHub Actions summary.
# Inputs: none.
# Output: appends markdown to $GITHUB_STEP_SUMMARY when available.
# Exit code: returns 0 unless the append fails.
ci_append_knowledge_note() {
  [ -f niro-knowledge.tar ] || return 0
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      printf '\n## Niro Knowledge Artifact\n\n'
      printf 'Download the `niro-knowledge` artifact and extract `niro-knowledge.tar` at the repo root to review and commit what Niro learned.\n'
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

# Purpose: configure GitHub Actions bot identity for fix-mode commits.
# Inputs: none.
# Output: updates git config.
# Exit code: returns 0 on success; git failures propagate.
ci_configure_git_author() {
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
}

# Purpose: validate GitHub token availability for fix mode.
# Inputs: mode (find|fix).
# Output: fatal error when fix mode lacks GitHub API auth.
# Exit code: returns 0 when auth requirements are satisfied; exits 2 otherwise.
ci_require_fix_auth() {
  local mode="$1"

  [ "$mode" = "fix" ] || return 0
  if [ -z "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
    niro_die "fix mode requires NIRO_PR_TOKEN to be exposed as GH_TOKEN and GITHUB_TOKEN"
  fi
}
