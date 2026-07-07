# CI Environment

This page documents the environment variables and secrets used by Niro CI
workflows.

## Configuration

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `NIRO_AGENT` | No | `claude` | Selects the agent Niro uses for the run. Supported values: `claude`, `codex`, and `copilot`. |
| `NIRO_CONFIG_DIR` | No | `niro` | Selects the Niro config directory under the project root. If it does not exist, the workflow initializes it. Set this when a repo keeps Niro config somewhere other than `niro/`, such as `niro-staging/` or `niro-prod/`. |
| `NIRO_GOAL` | Yes | - | Describes what Niro should do, such as `Pentest this app` or `Pentest and create PRs`. |
| `NIRO_MODEL` | No | agent default | Overrides the model used by the selected agent. Leave unset to use that agent's default model. |
| `NIRO_PROGRESS_FILE` | No | unset | When set, Niro creates the parent directory if needed and appends progress events as JSONL with `ts` and `message` fields, then streams them to the job log. |
| `NIRO_CI_ARTIFACT_INCLUDE_FINDINGS` | No | `true` | Controls whether Niro finding proof bundles are included in the CI artifact. Set to `false`, `0`, `no`, or `off` to exclude them. |
| `NIRO_CI_ARTIFACT_UPLOAD_DEBUG_LOGS` | No | `false` | Controls whether debug logs are uploaded as a CI artifact. Debug logs may contain secrets, captured tokens, and live request/response data. |

## Agent Authentication

Add the secret for the agent selected by `NIRO_AGENT`.

### GitHub Pull Requests

Only needed for workflows that create fix PRs (`niro-fix.yml`).

Niro authenticates to GitHub through a GitHub App rather than a personal
access token, so authentication does not expire during a long fix run. Create
the App once and add its credentials as secrets:

| Secret | Purpose |
| --- | --- |
| `NIRO_APP_CLIENT_ID` | The GitHub App's client ID. |
| `NIRO_APP_PRIVATE_KEY` | The GitHub App's private key — the full `-----BEGIN...END-----` PEM. |

To create the App:

1. Go to Settings → Developer settings → GitHub Apps → New GitHub App. For an
   organization's repositories, create the App under the **organization's**
   Developer settings, not your personal account — a private App can only be
   installed on the account that owns it.
2. Grant repository permissions **Contents: Read and write**, **Pull
   requests: Read and write**, and **Commit statuses: Read and write** (for
   the `Security / Niro` merge-gate check). Under **Webhook**, uncheck
   **Active** — Niro uses the App only for authentication, so it needs no
   webhook URL.
3. Install the App on the repositories Niro should open PRs against — and only
   those. The key can mint tokens for every repository the App is installed
   on, so a narrower install limits its reach.
4. Copy the **Client ID** into `NIRO_APP_CLIENT_ID`. On GitHub Enterprise
   Server, use the App's numeric **App ID** instead — GHES requires the App ID
   as the token issuer, not the client ID.
5. Generate a **private key**, then paste the downloaded `.pem` file's
   contents into `NIRO_APP_PRIVATE_KEY`.

No other configuration is required: `NIRO_APP_CLIENT_ID` (the App ID on GHES)
and `NIRO_APP_PRIVATE_KEY` are all Niro needs for both github.com and GitHub
Enterprise Server.

### Claude

| Secret | Purpose |
| --- | --- |
| `CLAUDE_CODE_OAUTH_TOKEN` | Authenticates Claude Code using a Claude subscription/OAuth token. |
| `ANTHROPIC_API_KEY` | Authenticates Claude Code using an Anthropic API key. |

To generate `CLAUDE_CODE_OAUTH_TOKEN`, run the Claude Code CLI locally and
complete the browser login it opens:

```bash
claude setup-token
```

This requires a Claude Pro, Max, Team, or Enterprise subscription (not an API
key). The command prints a one-year OAuth token and does not store it, so copy
the value into the `CLAUDE_CODE_OAUTH_TOKEN` secret yourself and regenerate it
before it expires. Use `ANTHROPIC_API_KEY` instead when you authenticate with an
Anthropic API key.

### Codex

| Secret | Purpose |
| --- | --- |
| `OPENAI_API_KEY` | Authenticates Codex with OpenAI. |
| `CODEX_AUTH_JSON_B64` | Optional alternative to API-key auth. Base64-encoded Codex `auth.json`; Niro restores it to `${CODEX_HOME:-$HOME/.codex}/auth.json` before running Codex. |

When `CODEX_HOME` is set, Codex expects that directory to already exist. Niro
creates it before restoring `auth.json`. If `CODEX_AUTH_JSON_B64` is not set,
Niro leaves Codex authentication alone, so Codex can use its configured
authentication, such as an existing login cache, `OPENAI_API_KEY`,
`CODEX_ACCESS_TOKEN`, or another Codex-supported provider setting.

`CODEX_AUTH_JSON_B64` is a static snapshot of a local Codex login. Codex may
refresh `auth.json` during a run, but GitHub-hosted runners discard the refreshed
file when the job ends. For recurring hosted runs, refresh this secret
periodically. For long-lived subscription-backed CI, prefer a self-hosted runner
with a persistent `CODEX_HOME` so Codex can refresh `auth.json` in place.

`CODEX_API_KEY` is intentionally not shown in the workflow examples. Codex
supports it for `codex exec`, but recommends setting it only for that single
process invocation rather than exposing it to the whole CI job environment.

To create the base64 value for `CODEX_AUTH_JSON_B64` from a local Codex login:

```bash
base64 < ~/.codex/auth.json | tr -d '\n'
```

### Copilot

The GitHub Actions examples use OpenRouter as the Copilot model provider.

| Variable | Value |
| --- | --- |
| `COPILOT_PROVIDER_BASE_URL` | `https://openrouter.ai/api/v1` |
| `COPILOT_PROVIDER_TYPE` | `openai` |
| `COPILOT_MODEL` | OpenRouter model name, such as `z-ai/glm-5.2` |

| Secret | Purpose |
| --- | --- |
| `OPEN_ROUTER_API_KEY` | Authenticates Copilot CLI with OpenRouter. |

## Application Secrets

Pass the same secrets your application needs to boot and run tests in CI. These
are only needed when the Niro job starts the app or test harness locally. If
Niro is testing an already-running staging or production target, authorize that
target in Niro scope instead of copying those runtime secrets into CI.

These are your app's normal runtime secrets, not Niro credentials.

Examples include `DATABASE_URL`, `REDIS_URL`, `JWT_SECRET`, `NEXTAUTH_SECRET`,
payment provider test keys, cloud credentials, and test user credentials.

Manage these as CI secrets and expose them to the Niro job the same way you
would for your existing test job.
