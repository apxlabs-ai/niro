# Recipes

Choose the workflow you need, then run the command from your project root. Make
sure you have completed the [prerequisites](prerequisites.md) first.

Niro is built around two commands:

- **`niro find`** pentests and reports. It does not create fix branches,
  commits, or pull requests, but it is not an OS-level read-only mode.
- **`niro fix`** pentests and opens review-ready PRs with the patch and
  validation evidence.

Claude Code is the default agent CLI. Add `--agent=copilot` or `--agent=codex`
to switch.

## Quick reference

| If you want to… | Jump to |
| --- | --- |
| Pentest everything and get PRs | [Fix the whole app](#fix-the-whole-app) |
| See the bugs without creating fixes | [Find only](#find-only) |
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

The exact same pentest, without fix branches, commits, or pull requests. Perfect
for a baseline audit, or when you just want the proof. Application preparation
and report generation can still write files; see the
[agent CLI privilege model](agent-cli-security.md).

```bash
niro find
```

Writes a proven findings summary to `niro-summary.md`.

## Target one area

Point Niro at a specific surface. The `--goal` flag takes plain English.

```bash
niro fix --goal "Pentest the billing API and its webhooks"
```

Swap `fix` for `find` if you want the report without fix branches or pull
requests.

## Pentest a pull request

Catch exploits before they reach your main branch without creating fixes.

```bash
niro find --pr-number 123
```

To run this check in CI, manually dispatch the reviewed pull-request workflow.
See [Run in CI](#run-in-ci). Autonomous runs have full current-user authority
on the runner, so the example does not start automatically on unreviewed pull
request code.

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
  runs a report-only sweep without a Git write credential;
  [`niro-fix.yml`](../examples/github-actions/niro-fix.yml) uses write
  permissions and a GitHub App to open fix PRs.
- **GitLab CI/CD:** [`niro-find.yml`](../examples/gitlab-ci/niro-find.yml) runs a
  report-only sweep; [`niro-fix.yml`](../examples/gitlab-ci/niro-fix.yml) uses a
  scoped GitLab token to open fix merge requests.

The examples also include commit-range and human-started pull-request or
merge-request workflows. See [Run Niro in CI](run-niro.md#run-in-ci) for the
complete matrix and [CI environment](ci-environment.md) for credentials and
configuration.

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
