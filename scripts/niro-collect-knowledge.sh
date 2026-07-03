#!/usr/bin/env bash
set -euo pipefail

out="${1:-niro-knowledge.tar}"
dir="${NIRO_CONFIG_DIR:-niro}"

# Fresh output each run: a stale archive from a previous run must not linger and
# get uploaded/reported when this run changed nothing.
rm -f "$out"

[ -d "$dir" ] || exit 0

# Never stage secrets or transient state. gitignore is the primary filter — the
# git commands below honor it — but these explicit excludes are a hard backstop
# for the four never-commit paths, so they hold even when the dir isn't
# gitignored (a custom NIRO_CONFIG_DIR may not be) or a secret was tracked before
# being ignored: real credentials, generated fixtures, per-finding proof bundles,
# and run state.
excludes=(
  ":(exclude)$dir/credentials.yaml"
  ":(exclude)$dir/fixtures.yaml"
  ":(exclude)$dir/findings"
  ":(exclude)$dir/harness/run"
)

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

# Include the repo-root .gitignore when it changed. niro init adds the
# never-commit entries (credentials, fixtures, findings, run state) there
# alongside the config dir, so committing this bundle without them would let a
# later generated secret under the config dir be tracked. Only when it actually
# changed; the developer reviews it like everything else in the bundle.
if [ -n "$(git status --porcelain --untracked-files=all -- .gitignore 2>/dev/null)" ]; then
  cp -a .gitignore "$staged/.gitignore" 2>/dev/null || true
fi

# Nothing staged -> no archive, so the caller's upload simply finds no file.
if [ -n "$(find "$staged" -type f 2>/dev/null)" ]; then
  tar -C "$staged" -cf "$out" .
fi
