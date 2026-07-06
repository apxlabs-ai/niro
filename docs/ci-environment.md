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
| `NIRO_PROGRESS_FILE` | No | unset | When set, Niro creates the parent directory if needed and appends progress events as JSONL with `ts` and `message` fields. CI wrappers can tail this file to stream progress to the job log. |
| `NIRO_CI_ARTIFACT_INCLUDE_FINDINGS` | No | `true` | Controls whether Niro finding proof bundles are included in the CI artifact. Set to `false`, `0`, `no`, or `off` to exclude them. |
| `NIRO_CI_ARTIFACT_UPLOAD_DEBUG_LOGS` | No | `false` | Controls whether debug logs are uploaded as a CI artifact. Debug logs may contain secrets, captured tokens, and live request/response data. |

## Agent Authentication

Add the secret for the agent selected by `NIRO_AGENT`.

### GitHub Pull Requests

Only needed for workflows that create fix PRs.

| Secret | Purpose |
| --- | --- |
| `NIRO_PR_TOKEN` | GitHub App or PAT token used to push branches and open fix PRs. Required for `niro-fix.yml`. |

### Claude

| Secret | Purpose |
| --- | --- |
| `CLAUDE_CODE_OAUTH_TOKEN` | Authenticates Claude Code using a Claude subscription/OAuth token. |
| `ANTHROPIC_API_KEY` | Authenticates Claude Code using an Anthropic API key. |

### Codex

| Secret | Purpose |
| --- | --- |
| `OPENAI_API_KEY` | Authenticates Codex with OpenAI. |
| `CODEX_AUTH_JSON_B64` | Optional alternative to API-key auth. Base64-encoded Codex `auth.json`; `niro-ci` restores this secret to `${CODEX_HOME:-$HOME/.codex}/auth.json` before running Codex. |

When `CODEX_HOME` is set, Codex expects that directory to already exist. The
`niro-ci` restore step creates it before restoring `auth.json`. If
`CODEX_AUTH_JSON_B64` is not set, `niro-ci` leaves Codex authentication alone,
so Codex can use its configured authentication, such as an existing login cache,
`OPENAI_API_KEY`, `CODEX_ACCESS_TOKEN`, or another Codex-supported provider
setting.

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
