# Recipes

**Copy, paste, pentest.** Find what you need, copy the command, and run it from
your project root. (Requires Niro and your [prerequisites](prerequisites.md)
installed.)

Niro is built around two commands:

- 🔍 **`niro find`** — pentests and reports. Read-only; never touches your code.
- 🛠️ **`niro fix`** — pentests *and* opens review-ready PRs with the patch and a
  regression test.

Both default to Claude Code — add `--agent=copilot` or `--agent=codex` to switch.

## Quick reference

| If you want to… | Jump to |
| --- | --- |
| Pentest everything and get PRs | [Fix the whole app](#-fix-the-whole-app) |
| See the bugs without changing code | [Find only](#-find-only) |
| Focus on a specific feature | [Target one area](#-target-one-area) |
| Check a PR before it merges | [Pentest a pull request](#-pentest-a-pull-request) |
| Test only the code that changed | [Pentest a diff](#-pentest-a-diff) |
| Automate Niro in GitHub Actions | [Wire it into CI](#-wire-it-into-ci) |
| Map out authorized targets first | [Draft a scope](#-draft-a-scope) |

## 🛠️ Fix the whole app

The default. Niro spins up your app, finds the exploits, and opens review-ready
PRs.

```bash
niro fix
```

Bugs are grouped by root cause — one PR per fix, each with its own regression
test. Review the diffs, merge what you want.

## 🔍 Find only

The exact same pentest, **zero code changes**. Perfect for a baseline audit, or
when you just want the proof.

```bash
niro find
```

Writes a proven findings summary to `niro-summary.md`.

## 🎯 Target one area

Point Niro at a specific surface — `--goal` takes **plain English**.

```bash
niro fix --goal "Pentest the billing API and its webhooks"
```

Swap `fix` for `find` if you just want the read-only report.

## 🛑 Pentest a pull request

Catch exploits before they reach your main branch (read-only).

```bash
niro find --pr-number 123
```

Want this automatic? Run Niro in CI on `pull_request` events — see
[Wire it into CI](#-wire-it-into-ci).

## 📏 Pentest a diff

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

## 🤖 Wire it into CI

Automate the **find → trust → fix** loop with two ready-to-copy GitHub Actions
workflows:

- **[`niro-find.yml`](../examples/github-actions/niro-find.yml)** — read-only
  sweeps (`contents: read`, no tokens). Start here.
- **[`niro-fix.yml`](../examples/github-actions/niro-fix.yml)** — opens fix PRs
  (needs write permissions and a GitHub App for auth).

Run them on a schedule or on pull requests. Secrets and config are in
[CI Environment](ci-environment.md).

## 🗺️ Draft a scope

If your app talks to APIs, webhooks, or third-party services, map them first — so
you don't accidentally attack an external target or silently miss an internal one.

```bash
niro draft scope https://app.example.com
```

Niro browses the app and writes `scope.draft.yaml` — every host it reached.
Review it, keep the hosts you own, and rename it to `scope.yaml` to authorize
testing. Niro never authorizes a target on its own.
