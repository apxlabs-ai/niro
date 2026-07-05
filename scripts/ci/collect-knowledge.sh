#!/usr/bin/env bash
#
# Purpose: prepare the Niro knowledge tarball for CI artifact upload.
# Inputs:
#   $1                                  optional output tar path; defaults to niro-knowledge.tar
#   NIRO_CONFIG_DIR                     required Niro config directory
#   NIRO_CI_ARTIFACT_INCLUDE_FINDINGS   optional; false/0/no/off excludes findings
# Output: creates the tarball when there is knowledge to upload; otherwise no file.
# Exit code: 0 on success or no-op; non-zero on missing required input or command failure.
#
set -euo pipefail

out="${1:-niro-knowledge.tar}"
dir="${NIRO_CONFIG_DIR:?NIRO_CONFIG_DIR is required}"

# Fresh output each run: a stale archive from a previous run must not linger and
# get uploaded/reported when this run changed nothing.
rm -f "$out"

[ -d "$dir" ] || exit 0

# Normalize NIRO_CONFIG_DIR to a clean repo-relative path. It may arrive
# absolute (/workspace/niro-prod), or as ./niro, niro/, or niro// — and
# the git pathspecs, archive layout, and .gitignore rule below all need a
# canonical repo-relative form (a rule like ./niro/findings/ or niro//findings/
# does not actually ignore niro/findings/). Resolve physically (so a /var vs
# /private/var symlink on macOS can't defeat the strip) and strip the repo root.
absdir=$(cd "$dir" 2>/dev/null && pwd -P)
root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -n "$root" ] && root=$(cd "$root" 2>/dev/null && pwd -P)
if [ -n "$absdir" ] && [ -n "$root" ]; then
  case "$absdir" in "$root"/*) dir="${absdir#"$root"/}" ;; esac
fi

# The git selection below stages the committable config. These excludes keep the
# four never-commit paths out of that selection — a hard backstop beyond gitignore,
# so it holds even for a non-gitignored custom NIRO_CONFIG_DIR or a secret tracked
# before being ignored. credentials, fixtures, and run state stay out entirely
# (pure secrets/state). findings is excluded here too, then re-added below for
# INSPECTION only — it's gitignored, so it rides in the download but is never
# committed.
excludes=(
  ":(exclude)$dir/credentials.yaml"
  ":(exclude)$dir/fixtures.yaml"
  ":(exclude)$dir/findings"
  ":(exclude)$dir/harness/run"
)

gitignore_entries=(
  "$dir/credentials.yaml"
  "$dir/fixtures.yaml"
  "$dir/findings/"
  "$dir/harness/run/"
)

# Purpose: ensure the staged artifact contains .gitignore rules for local-only Niro files.
# Inputs: uses staged temp directory and gitignore_entries array.
# Output: creates or updates $staged/.gitignore.
# Exit code: returns 0 on success; write failures propagate.
ensure_staged_gitignore() {
  local gitignore="$staged/.gitignore"
  local entry

  if [ ! -f "$gitignore" ] && [ -f .gitignore ]; then
    cp -a .gitignore "$gitignore" 2>/dev/null || true
  fi
  touch "$gitignore"
  if [ -s "$gitignore" ] && [ -n "$(tail -c1 "$gitignore" 2>/dev/null)" ]; then
    printf '\n' >> "$gitignore"
  fi
  for entry in "${gitignore_entries[@]}"; do
    if ! grep -qxF "$entry" "$gitignore" 2>/dev/null; then
      printf '%s\n' "$entry" >> "$gitignore"
    fi
  done
}

# Stage into a temp tree first (cp -a preserves modes and hidden files), then
# archive it. A plain directory artifact would lose executable bits (harness
# scripts get restored as 644) and drop dotfiles like .gitignore (upload-artifact
# skips hidden files by default) — a tar preserves both; the developer extracts
# it over their repo root and commits.
staged=$(mktemp -d)
trap 'rm -rf "$staged"' EXIT

# Stage what Niro learned about the app this run: the changed or newly created
# committable files under the config dir (scope, harness scripts,
# accepted-behaviors). Letting git select keeps this in lockstep with what niro
# init gitignores, with no second exclude list to drift. Null-delimited to
# survive odd filenames; deletions are skipped (nothing to copy). Best-effort per
# file so one bad copy can't abort the rest.
{ git diff --name-only -z HEAD -- "$dir" "${excludes[@]}" 2>/dev/null
  git ls-files --others --exclude-standard -z -- "$dir" "${excludes[@]}" 2>/dev/null
} | while IFS= read -r -d '' f; do
  [ -e "$f" ] || continue
  mkdir -p "$staged/$(dirname "$f")"
  cp -a "$f" "$staged/$f" 2>/dev/null || true
done

# Include the repo-root .gitignore when it changed. Only when it actually
# changed; the developer reviews it like everything else in the bundle.
if [ -n "$(git status --porcelain --untracked-files=all -- .gitignore 2>/dev/null)" ]; then
  cp -a .gitignore "$staged/.gitignore" 2>/dev/null || true
fi

# NIRO_CI_ARTIFACT_INCLUDE_FINDINGS (default true) rides the run's proof bundles
# along for inspection. Set it false on a public repo, where this
# world-downloadable archive shouldn't carry the raw payloads and captured
# values a finding's PoC contains.
case "${NIRO_CI_ARTIFACT_INCLUDE_FINDINGS:-true}" in 0|false|FALSE|no|NO|off|OFF) include_findings=no ;; *) include_findings=yes ;; esac

# Bundle the findings/ proof bundles — for INSPECTION, not committing (finding.json
# + a reproduction per finding: how a developer verifies and acts on what Niro
# found). Copied explicitly because git ignores findings/ (the selection above
# skips them). Skipped when findings are already tracked — copying over tracked
# paths would stage modifications that .gitignore can't prevent. These carry real
# payloads/captured values: the archive is only as private as the repo it's
# uploaded from.
if [ "$include_findings" = yes ] && [ -d "$dir/findings" ] \
   && [ -n "$(ls -A "$dir/findings" 2>/dev/null)" ] \
   && [ -z "$(git ls-files -- "$dir/findings" 2>/dev/null)" ]; then
  mkdir -p "$staged/$dir"
  cp -a "$dir/findings" "$staged/$dir/" 2>/dev/null || true
fi

# Nothing staged -> no archive, so the caller's upload simply finds no file.
if [ -n "$(find "$staged" -type f 2>/dev/null)" ]; then
  # Guarantee the bundle protects local-only Niro files for the selected config
  # dir, even when the repository's committed .gitignore only has default niro/
  # entries or the caller uses a custom NIRO_CONFIG_DIR. Do this only after
  # real content exists, so a clean run does not upload a .gitignore-only
  # artifact.
  ensure_staged_gitignore
  tar -C "$staged" -cf "$out" .
fi
