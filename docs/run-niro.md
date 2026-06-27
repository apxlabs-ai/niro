# Run Niro

Niro has two independent choices:

- **Where it runs:** local or CI.
- **What it tests:** whole app, focused scope, or pull request.

## Before You Install

For local use, Niro orchestrates tools you already use. You'll need:

- **Container runtime**
  - [Docker](https://docs.docker.com/get-started/get-docker/)
  - [Podman](https://podman.io/docs/installation)
- **Git**
  - [Git downloads](https://git-scm.com/downloads)
- **Code host CLI**
  - [GitHub CLI](https://cli.github.com/)
  - [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- **Supported coding agent**
  - [Claude Code](https://code.claude.com/docs/en/overview)
  - [OpenAI Codex](https://developers.openai.com/codex/cli)
  - [GitHub Copilot](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli)

Need GitLab, Cursor, or another environment? Open an
[issue](https://github.com/apxlabs-ai/niro/issues).

## Install

**macOS, Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh | sh
```

**Windows PowerShell:**

```powershell
irm https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.ps1 | iex
```

For security-conscious environments, download and inspect the
[install script](https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh)
before running it, or install from the
[Releases page](https://github.com/apxlabs-ai/niro/releases).

## Initialize A Repo

From the root of your repo:

```bash
niro init
```

This scaffolds a `niro/` directory and wires Niro into your coding agent as an
MCP server. Commit the generated project setup so the team shares the same
configuration.

## Local Runs

Use local mode when a developer wants Niro available from their existing coding
agent workflow.

Local runs are useful when you want to:

- bring up the app from your working tree;
- inspect the harness Niro creates;
- tune scope, fixtures, credentials, and accepted behavior;
- review PR branches before pushing or merging.

### Goal-Based Run

Ask your coding agent to run a whole-app pentest or target a focused area:

```bash
claude "Pentest this application and create PRs."
codex exec "Pentest the billing API and create PRs."
```

### PR Run

Use a PR run when you want Niro to test changes before they merge:

```bash
claude "Pentest the current pull request."
codex exec "Pentest the current pull request."
```

## CI Runs

Use CI mode when you want a repeatable workflow that can pentest the app and
open fix PRs without a developer sitting at the keyboard.

The Niro runner image includes Niro, common CI/runtime dependencies, browser
tooling, Docker client/Compose, GitHub CLI, and supported coding-agent CLIs.
The checked-out customer repo still controls app setup, secrets, credentials,
and network access.

### Full Or Focused Run

Use the open-PRs workflow when you want CI to pentest the app and open
review-ready fix PRs.

See the [GitHub Actions open-PRs workflow example](../examples/github-actions/niro-open-prs.yml).

### PR Run

CI PR-run support is coming soon.

## Runtime And Cost

Runtime and cost depend on app size, setup, scope, model choice, and
concurrency. Small focused runs can finish in minutes; whole-app pentest-to-PR
runs often take 2-6 hours, depending on app size and setup.

Use `niro.yaml` to control time, cost, and concurrency:

```yaml
limits:
  max_budget_usd: 15
  max_duration_minutes: 120
  max_concurrency: 4
```

## Configuration

For harness, scope, credentials, fixtures, accepted behavior, and coverage-gap
handling, see [Pentesting Without The Setup Tax](pentesting-without-the-setup-tax.md).
