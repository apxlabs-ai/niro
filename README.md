# Niro

> Push a PR. Niro hacks it. Your agent patches it.
>
> Security that keeps pace with AI-speed shipping — found and fixed before you merge.

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
happens at all. Niro closes that gap: testing runs in the same loop as the
code, before CI finishes. No Jira ticket. No triage queue.

You review a clean PR.

## Pentesting Without the Setup Tax

Most pentests stall before testing starts. The app needs realistic users,
tenants, resources, webhooks, integrations, feature flags, and product state
before meaningful bugs are reachable.

Niro turns that setup work into an agent loop. Your coding agent prepares the
context, Niro reports what is still missing, and the agent fills the gaps and
re-runs. The developer stays in review mode instead of manually building a
pentest harness.

See [how the setup loop works](docs/pentesting-without-the-setup-tax.md).

## Commitments

- Findings in under 8 minutes (P80)
- Under $3 in model spend per run (P80)

Both are commitments, not averages — they're the floor the product is
engineered around.

## Before you install

Niro orchestrates tools you already use — it doesn't bundle them. You'll
need:

- **Container runtime** — one of:
  - [Docker](https://docs.docker.com/get-started/get-docker/)
  - [Podman](https://podman.io/docs/installation)
- **CLIs:**
  - [Git](https://git-scm.com/downloads)
  - your code host's CLI — one of:
    - [GitHub](https://cli.github.com/)
    - [Azure DevOps](https://learn.microsoft.com/cli/azure/install-azure-cli)
- **Coding agent** (installed locally) — one of:
  - [Claude Code](https://code.claude.com/docs/en/overview)
  - [GitHub Copilot](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli)
  - [OpenAI Codex](https://developers.openai.com/codex/cli)

Need GitLab, Cursor, or something else? [Open an
issue](https://github.com/apxlabs-ai/niro/issues) — we prioritize by demand.
Runs on macOS, Linux, and Windows.

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

**Commit the `niro/` directory and agent wiring** (`.mcp.json`, `.claude/`,
etc.) so your whole team inherits the setup on the next pull — no one else
needs to run `niro init`.

> [!TIP]
> Want to evaluate Niro on a whole application and have your agent open fix
> PRs? See [Full Pentest to Fix PRs](docs/full-pentest-to-fix-prs.md).

## What you control

- **Pentest engine** runs in a local sandbox with default-deny egress. The
  only reachable endpoints are the targets you list in `niro/scope.yaml`.
- **Niro plugs into the coding agent you already use** — such as Claude
  Code, GitHub Copilot, or OpenAI Codex — and lets it do the reasoning. Your
  agent calls its LLM provider directly using the credentials already in your
  shell. Niro doesn't have an API key and doesn't see yours. The bill arrives
  on your provider account.
- **Telemetry is opt-out.** When a pentest completes, Niro sends one usage
  event. See [TELEMETRY.md](TELEMETRY.md) for the full details and how to turn
  it off.

## License

Apache License 2.0 ([LICENSE](LICENSE), [NOTICE](NOTICE)). Install, run,
redistribute, and build on Niro freely.

## Issues

<https://github.com/apxlabs-ai/niro/issues>
