# Niro

> Push a PR. Niro hacks it. Your agent patches it.

A PR adds a saved-search feature to your app. Niro reports 4 cross-tenant
data leaks in under 6 minutes for $2.84 in model spend. Your coding agent
writes a regression test for each, patches the code, and re-runs Niro to
verify the fix. The PR goes green.

That's the loop.

## What a run looks like

1. Push a PR. Your coding agent calls Niro.
2. Niro pentests your running app — scoped to what the PR changed — and
   returns each finding with the exact HTTP request that proved it.
3. Your agent writes a failing regression test, patches the code, and asks
   Niro to re-verify.
4. Niro posts a green check on the PR. Merge.

## Why Niro?

Your AI agent ships code in minutes. Security testing takes days — if it
happens at all. Niro closes that gap. Your agent calls it, gets
reproducible exploits back, patches the code, and re-runs Niro to verify —
all in the same loop, before CI finishes. No Jira ticket. No triage queue.

You review a clean PR.

## Commitments

- Findings in under 8 minutes (P80)
- Under $3 in model spend per run (P80)

Both are commitments, not averages — they're the floor the product is
engineered around.

## Before you install

Niro orchestrates tools you already use — it doesn't bundle them. You'll
need:

- **Container runtime:** Docker or Podman
- **Git**, plus the CLI for your code host: `gh` (GitHub) or `az` (Azure
  DevOps)
- **Coding agent:** Claude Code (`claude`) or GitHub Copilot (`copilot`)
  installed locally

Codex (`codex`) support is coming soon. Need GitLab, Cursor, or something
else? [Open an issue](https://github.com/apxlabs-ai/niro/issues) — we
prioritize by demand. Runs on macOS, Linux, and Windows.

## Install

**macOS, Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.ps1 | iex
```

## Quickstart

From the root of your repo:

```bash
niro init
```

This scaffolds a `niro/` directory and wires Niro into your coding agent as
an MCP server. Your agent decides when to call it from there — typically
right before a push.

## What you control

- **Pentest engine** runs in a local sandbox with default-deny egress. The
  only reachable endpoints are the targets you list in `niro/scope.yaml`.
- **Niro plugs into the coding agent you already use** — Claude Code or
  GitHub Copilot — and lets it do the reasoning. Your agent calls its LLM
  provider directly using the credentials already in your shell. Niro
  doesn't have an API key and doesn't see yours. The bill arrives on your
  provider account.
- **No telemetry.** Niro doesn't phone home — no metrics, no analytics, no
  logs sent to our servers. Your code, findings, and runs stay on your
  machine.

## License

Apache License 2.0 ([LICENSE](LICENSE), [NOTICE](NOTICE)). Install, run,
redistribute, and build on niro freely.

## Issues

<https://github.com/apxlabs-ai/niro/issues>
