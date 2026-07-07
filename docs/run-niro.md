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

## Trust Boundaries

Niro runs in your local or CI environment. App traffic, credentials, test
state, and generated artifacts stay there unless your workflow explicitly
uploads or commits them.

Niro uses the AI provider account configured through your coding agent. That
provider may receive the context needed for reasoning, such as relevant code
snippets, command output, errors, HTTP observations, and remediation context.
Review your provider's data-retention and training terms before using Niro with
sensitive systems.

Niro does not require uploading your repository, credentials, findings, or logs
to a Niro backend to complete a local or CI run.

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

Run Niro directly on the CI runner VM: `niro ci find` pentests the app and
reports findings, and `niro ci fix` also opens review-ready fix PRs. Docker
remains a host prerequisite, just like local runs.

### Full Or Focused Run

There are two GitHub Actions examples, matching **find → trust → fix**:

- [`niro-find.yml`](../examples/github-actions/niro-find.yml) — read-only. Pentests
  the app and reports the findings without touching your repo (`contents: read`,
  no tokens, no setup). Start here.
- [`niro-fix.yml`](../examples/github-actions/niro-fix.yml) — pentests the app and
  opens review-ready fix PRs. Needs write permissions; see the note by its
  `permissions:` block about enabling PR creation.

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

For CI environment variables and secrets, see
[CI Environment](ci-environment.md).

## FAQ

### What is MCP?

[Model Context Protocol](https://modelcontextprotocol.io/docs/getting-started/intro)
is an open standard that lets AI applications connect to external tools and
systems. After `niro init`, your coding agent can call Niro through MCP to
scope, test, verify, and remediate the application from the current repo.

### Does Niro replace a compliance pentest?

No. Niro is designed for continuous pentest-to-fix work during development and
CI. It helps reduce risk before formal audits or third-party pentests, but does
not by itself replace auditor-required testing.

### Will Niro upload logs or artifacts?

No, not by default. Local runs keep artifacts on your machine. CI workflows only
upload artifacts if the workflow is configured to do so.

### Can I stop a long run?

Yes. Stop the coding-agent process from your terminal or cancel the CI job. Any
opened PRs, committed branches, or written artifacts remain for review.
