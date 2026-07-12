# Recipes

Choose the workflow you need, then run the command from your project root. Make
sure you have completed the [prerequisites](prerequisites.md) first.

Niro is built around two commands:

- **`niro find`** pentests and reports. It does not change your code.
- **`niro fix`** pentests and opens review-ready PRs with the patch and
  validation evidence.

Claude Code is the default agent CLI. Add `--agent=copilot` or `--agent=codex`
to switch.

## Quick reference

| If you want to… | Jump to |
| --- | --- |
| Pentest everything and get PRs | [Fix the whole app](#fix-the-whole-app) |
| See the bugs without changing code | [Find only](#find-only) |
| Focus on a specific feature | [Target one area](#target-one-area) |
| Check a PR before it merges | [Pentest a pull request](#pentest-a-pull-request) |
| Test only the code that changed | [Pentest a diff](#pentest-a-diff) |
| Automate Niro in CI | [Run in CI](#run-in-ci) |
| Map out authorized targets first | [Draft a scope](#draft-a-scope) |

## Fix the whole app

The default. Niro spins up your app, finds the exploits, and opens review-ready
PRs.

```bash
niro fix
```

Bugs are grouped by root cause: one PR per fix, each with its own validation
evidence. Review the diffs, merge what you want.

## Find only

The exact same pentest, **zero code changes**. Perfect for a baseline audit, or
when you just want the proof.

```bash
niro find
```

Writes a proven findings summary to `niro-summary.md`.

## Target one area

Point Niro at a specific surface. The `--goal` flag takes plain English.

```bash
niro fix --goal "Pentest the billing API and its webhooks"
```

Swap `fix` for `find` if you just want the read-only report.

## Pentest a pull request

Catch exploits before they reach your main branch (read-only).

```bash
niro find --pr-number 123
```

To automate this check, run Niro in CI on `pull_request` events. See
[Run in CI](#run-in-ci).

## Pentest a diff

Test only what changed between two commits. Commit ranges are immutable, so this
is the most precise way to scope a run.

```bash
niro find --base-sha <base> --head-sha <head>
```

For example, everything since your last release:

```bash
niro find --base-sha "$(git rev-parse v1.4.0)" --head-sha HEAD
```

Swap `find` for `fix` to open fixes for just that diff.

## Run in CI

Use the ready-to-copy workflows for your CI provider:

- **GitHub Actions:** [`niro-find.yml`](../examples/github-actions/niro-find.yml)
  runs a read-only sweep without a Git write credential;
  [`niro-fix.yml`](../examples/github-actions/niro-fix.yml) uses write
  permissions and a GitHub App to open fix PRs.
- **GitLab CI/CD:** [`niro-find.yml`](../examples/gitlab-ci/niro-find.yml) runs a
  read-only sweep; [`niro-fix.yml`](../examples/gitlab-ci/niro-fix.yml) uses a
  scoped GitLab token to open fix merge requests.

The examples also include commit-range and pull-request or merge-request
workflows. See [Run Niro in CI](run-niro.md#run-in-ci) for the complete matrix
and [CI environment](ci-environment.md) for credentials and configuration.

## Draft a scope

If your app talks to APIs, webhooks, or third-party services, map them first so
you do not accidentally attack an external target or silently miss an internal
one.

```bash
niro draft scope https://app.example.com
```

Niro browses the app and writes every host it reached to `scope.draft.yaml`.
Review it, keep the hosts you own, and rename it to `scope.yaml` to authorize
testing. Niro never authorizes a target on its own.
