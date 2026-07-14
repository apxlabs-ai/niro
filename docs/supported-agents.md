# Supported agent CLIs

Niro works with Claude Code, OpenAI Codex, and GitHub Copilot CLI. Choose the
agent CLI you already use, authenticate it normally, and select it when you run
Niro.

Niro invokes the selected CLI in your local or CI environment. The CLI talks
directly to the AI provider you configure; Niro does not proxy model requests
through a Niro-hosted service. See [Security and data](security-and-data.md) for
the complete data flow and trust boundaries.

## Terminology

| Term | Meaning |
| --- | --- |
| Agent CLI | The customer-installed Claude Code, Codex, or Copilot executable selected by `--agent` |
| Developer agent | The host-side role that prepares code changes and validation evidence |
| Attacker agent | The host-side reasoning role that finds and proves vulnerabilities |
| Attack-tool sandbox | The Docker or Podman container where command-line and browser tools execute |

The developer agent and attacker agent run on your workstation or CI runner
through the selected agent CLI. Neither runs inside the attack-tool sandbox.

## Choose an agent CLI

| Agent CLI | Select it | Install |
| --- | --- | --- |
| Claude Code | Default | [Claude Code installation](https://code.claude.com/docs/en/overview) |
| OpenAI Codex | `--agent=codex` | [Codex CLI installation](https://developers.openai.com/codex/cli) |
| GitHub Copilot CLI | `--agent=copilot` | [Copilot CLI installation](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli) |

Claude Code is the default when `--agent` is omitted. Agent CLI selection applies
to the current command; it is not a persistent global setting.

Niro uses an agent CLI already available on `PATH`. For turnkey `find` and `fix`
runs, Niro can install a missing agent CLI from its official npm package when
npm is available. Install it yourself first when you need to control the agent
CLI version or installation method.

This requirement applies to Claude Code, Codex, and Copilot CLI equally. Niro
uses the `PATH` inherited by its process and does not scan common installation
directories or select an SDK-bundled CLI. When an MCP client launches Niro,
ensure that client passes a `PATH` containing its agent CLI executable.

## Run with your agent CLI

Use the same `--agent` flag with `niro find` or `niro fix`:

```bash
# Claude Code (default)
niro fix

# OpenAI Codex
niro fix --agent=codex

# GitHub Copilot CLI
niro fix --agent=copilot
```

For a report-only run, replace `fix` with `find`.

## Choose interactive or autonomous execution

Turnkey local runs are interactive by default. Niro launches the selected agent
CLI in the current terminal and automatically submits the first message:

```bash
niro find --goal "Test the login flow"
```

Claude Code, Codex, or Copilot CLI then displays its native permission requests.
The user can approve, deny, or steer the session before control returns to Niro.

Pass `--autonomous` to run without those approval prompts:

```bash
niro find --autonomous --goal "Test the login flow"
```

Autonomous mode grants the selected agent CLI the unattended execution
authority documented by that product, including the ability to run project
commands with full current-user host access. Niro does not enable it from
repository configuration or infer it from CI. CI and other non-interactive
environments must pass `--autonomous` explicitly or Niro exits before
orchestration. See [Agent CLI privileges and threat
model](agent-cli-security.md) for the exact provider mechanisms and
non-controls.

The agent CLI and the model provider are separate choices:

- The **agent CLI** is the executable Niro invokes: Claude Code, Codex, or
  Copilot CLI.
- The **provider** supplies model inference and bills your account.
- The **model** is selected through that agent CLI's own configuration.

Selecting `--agent=codex`, for example, selects the Codex CLI; it does not
change Codex's configured model. See [Model selection](model-selection.md) for
model controls for the developer agent and the attacker agent.

### Run Niro from an interactive developer agent session

The turnkey `niro find` and `niro fix` commands initialize Niro automatically.
To start pentests by prompting your developer agent in an interactive session,
initialize the integration once:

```bash
niro init --agent=codex
```

Replace `codex` with `claude` or `copilot`, restart the agent CLI so it loads
Niro's project integration, then ask it to run a pentest. For example:

```text
Pentest this application and create fix PRs.
```

## Authenticate locally

Start the agent CLI once and complete its normal sign-in flow. Niro reuses the
credentials that the agent CLI already has; there is no separate Niro login.

| Agent CLI | Local authentication |
| --- | --- |
| Claude Code | Start `claude`, then sign in with `/login`, or configure an Anthropic API key or supported cloud provider. |
| OpenAI Codex | Start `codex` and sign in, or configure an API key or provider in Codex. |
| GitHub Copilot CLI | Start `copilot`, then sign in with `/login`, or configure a custom provider. |

Verify that the selected CLI is available before starting a long run:

```bash
claude --version
codex --version
copilot --version
```

You only need the command for the agent CLI you plan to use.

## Authenticate in CI

CI runners cannot complete an interactive browser login. Add credentials for
the selected agent CLI to your CI secret store, and expose only that agent CLI's
credentials to the Niro job.

Never commit an API key, OAuth token, access token, or encoded credential file.
Base64 encoding is not encryption.

| Agent CLI | Recommended CI authentication | Alternative |
| --- | --- | --- |
| Claude Code | `ANTHROPIC_API_KEY` | `CLAUDE_CODE_OAUTH_TOKEN` |
| OpenAI Codex | `OPENAI_API_KEY` | `CODEX_AUTH_JSON_B64` |
| GitHub Copilot CLI | `COPILOT_GITHUB_TOKEN` | Custom provider configuration |

### Claude Code

Use one of these secrets:

| Secret | Purpose |
| --- | --- |
| `ANTHROPIC_API_KEY` | Uses direct Anthropic API billing. |
| `CLAUDE_CODE_OAUTH_TOKEN` | Uses an eligible Claude subscription for noninteractive runs. |

Generate a long-lived subscription token locally:

```bash
claude setup-token
```

The command walks through OAuth authorization and prints a one-year token. It
does not save the token. Store the result as `CLAUDE_CODE_OAUTH_TOKEN` in your
CI secret store and rotate it before it expires. This path requires an eligible
Claude Pro, Max, Team, or Enterprise subscription.

When `ANTHROPIC_API_KEY` and subscription credentials are both present, Claude
Code uses the API key for noninteractive execution. Unset the API key when you
intend to use subscription billing, and use `/status` in Claude Code to confirm
the active authentication method. See [Claude Code authentication](https://code.claude.com/docs/en/team)
for current credential precedence and subscription terms.

Claude Code can also use Amazon Bedrock, Google Vertex AI, Microsoft Foundry,
and compatible gateways. Configure those through Claude Code's provider
settings; Niro does not replace that configuration.

### OpenAI Codex

For hosted CI, prefer an API key:

| Secret | Purpose |
| --- | --- |
| `OPENAI_API_KEY` | Authenticates Codex with OpenAI in the CI job. |
| `CODEX_AUTH_JSON_B64` | Restores a snapshot of an existing Codex login when API-key authentication is not suitable. |

`CODEX_AUTH_JSON_B64` is a Niro CI helper, not a new authentication format. Niro
decodes it into `${CODEX_HOME:-$HOME/.codex}/auth.json` before starting Codex
and removes the encoded value from the child-process environment.

Create the value from an existing local login.

macOS or Linux:

```bash
base64 < ~/.codex/auth.json | tr -d '\n'
```

Windows PowerShell:

```powershell
$path = Join-Path $HOME ".codex/auth.json"
[Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
```

Treat the result like a password: store it only as a masked CI secret, never
print it in logs, and never commit it. It is a static snapshot. Codex may refresh
`auth.json` during a run, but an ephemeral hosted runner discards the refreshed
file when the job ends. Refresh the secret periodically, or use a self-hosted
runner with a persistent `CODEX_HOME` when subscription-backed CI needs durable
credential refresh.

If `CODEX_AUTH_JSON_B64` is absent, Niro leaves Codex authentication unchanged
so Codex can use its normal login, API-key, or provider configuration.

### GitHub Copilot CLI

Copilot offers two distinct CI paths: native Copilot authentication or a custom
model provider.

#### Native Copilot

Use `COPILOT_GITHUB_TOKEN` to avoid colliding with credentials used by other Git
or GitHub tooling. Copilot also recognizes `GH_TOKEN` and `GITHUB_TOKEN`, but an
environment variable overrides a stored interactive login. The token must be
eligible for Copilot CLI requests; a classic personal access token is not
supported.

See [Authenticating Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/authenticate-copilot-cli)
for supported token types, required permissions, and credential precedence.

#### Custom model provider

Configure all four variables, or none of them:

```bash
export COPILOT_PROVIDER_TYPE=openai
export COPILOT_PROVIDER_BASE_URL=https://openrouter.ai/api/v1
export COPILOT_PROVIDER_API_KEY=<provider-key>
export COPILOT_MODEL=<tool-capable-model-id>
```

| Variable | Purpose |
| --- | --- |
| `COPILOT_PROVIDER_TYPE` | Provider API dialect: `openai`, `azure`, or `anthropic`. |
| `COPILOT_PROVIDER_BASE_URL` | Provider API endpoint. |
| `COPILOT_PROVIDER_API_KEY` | Credential sent to that provider. Niro currently requires a non-empty value. |
| `COPILOT_MODEL` | Provider-specific model identifier. |

A partial configuration may fail before the pentest begins or leave the run
without usable native Copilot authentication. Keep these variables together in
the same CI environment or secret group.

The selected model must support tool calling and streaming. GitHub recommends a
context window of at least 128k tokens for Copilot CLI. See [Using your own model
provider](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-copilot-cli#using-your-own-model-provider)
for current compatibility requirements.

With a custom Copilot provider, `COPILOT_MODEL` also becomes Niro's default for
reasoning tiers for the attacker agent that are not pinned in `niro.yaml`. See
[Model selection](model-selection.md) when you need separate models for the
developer agent and the attacker agent.

## Verify your setup

After the agent CLI is installed and authenticated, run a focused assessment
before launching a whole-app pentest:

```bash
niro find --agent=codex --goal "Test the login and session flows"
```

Change the `--agent` flag or omit it for Claude Code. A successful run confirms
the agent CLI login, provider access, container runtime, and Niro project setup
together.
Use `niro fix` only when the Git provider is also authenticated and you are ready
for Niro to open fix pull requests.

For workflow examples and Git-provider permissions, continue to
[Run Niro in CI](run-niro.md#run-in-ci) and [CI environment](ci-environment.md).
