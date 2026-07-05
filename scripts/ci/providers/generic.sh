#!/usr/bin/env bash

# Purpose: identify the CI provider for provider-specific integration points.
# Inputs: CI provider environment variables.
# Output: prints github-actions or generic.
# Exit code: returns 0.
ci_detect_provider() {
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    printf 'github-actions\n'
  else
    printf 'generic\n'
  fi
}

# Purpose: resolve the checked-out workspace directory.
# Inputs: none.
# Output: prints the current working directory.
# Exit code: returns 0.
ci_workspace() {
  printf '%s\n' "$(pwd)"
}

# Purpose: resolve a temp directory for run summaries and scratch files.
# Inputs: TMPDIR optional environment variable.
# Output: prints a temp directory path.
# Exit code: returns 0.
ci_temp_dir() {
  printf '%s\n' "${TMPDIR:-/tmp}"
}

# Purpose: describe the run environment to the agent, appended to its goal.
# Inputs: none.
# Output: prints provider-neutral facts (no artifact/preservation claims —
#   the generic path uploads nothing and may be a local invocation).
# Exit code: returns 0.
ci_run_context() {
  printf '%s' "You are running non-interactively — there is no user to prompt or hand back to during this run."
}

# Purpose: append a markdown file to the CI job summary when supported.
# Inputs: summary file path.
# Output: no-op for generic CI.
# Exit code: returns 0.
ci_append_summary() {
  return 0
}

# Purpose: append the knowledge-artifact note to the CI job summary when supported.
# Inputs: none.
# Output: no-op for generic CI.
# Exit code: returns 0.
ci_append_knowledge_note() {
  return 0
}

# Purpose: configure git author identity for fix-mode commits.
# Inputs: none.
# Output: updates git config with a generic CI identity.
# Exit code: returns 0 on success; git failures propagate.
ci_configure_git_author() {
  git config user.name "niro-ci"
  git config user.email "niro-ci@localhost"
}

# Purpose: validate fix-mode forge authentication.
# Inputs: mode (find|fix).
# Output: no-op for generic CI.
# Exit code: returns 0.
ci_require_fix_auth() {
  return 0
}
