# CI Environment

This page documents the environment variables and secrets used by Niro CI
workflows.

Every CI invocation of `niro find` or `niro fix` must pass `--autonomous`.
Without that explicit grant, Niro exits before repository initialization,
agent CLI execution, or model-provider access because no interactive terminal
is available for approvals. The flag grants full current-user host access
without agent CLI approval prompts. Use an ephemeral, least-privilege runner,
expose only required secrets, and run only a revision reviewed for autonomous
execution. See [Agent CLI privileges and threat
model](agent-cli-security.md). The ready-to-copy workflows include the flag.

## Model selection

Niro does not set the developer agent's model. Use the selected agent CLI's
own mechanism:
`COPILOT_MODEL` for Copilot, `ANTHROPIC_MODEL` for Claude, or Codex's config.

Niro's task-specific model tiers are pinned in `niro.yaml`'s `models:` block.
For Claude and Codex, the attacker agent's tiers are independent of the
developer agent's model.
**Copilot is the exception:** a BYOK provider serves a single model, so
`COPILOT_MODEL` also becomes the default for every tier that `niro.yaml` does
not pin. To use different models, pin `models.high`, `models.medium`, and
`models.low` in `niro.yaml`.

## Agent CLI authentication

Add the secret for the agent CLI you run (`--agent`, default `claude`).

### GitHub Pull Requests

PR-scoped find (`niro-find-pr.yml`) is manually dispatched with the PR number
and full reviewed head commit SHA. It verifies that head against the PR and
checks it out. The Niro process reads the checkout's `HEAD`, verifies it against
the live PR, and captures the PR's base and head from that same forge response.
Niro excludes mutable PR title/body text from the autonomous run and posts the
merge-gate status to the captured head. The workflow posts its comment with the
built-in `GITHUB_TOKEN`
(grant `contents: read` + `pull-requests` / `statuses: write` — a `permissions:`
block defaults every unlisted scope to `none`) — no App required.
For private repositories, a repository-local `gh auth git-credential` helper
authenticates Niro's read-only Git fetches without storing the token in Git
configuration.

Copy GitHub's current head before dispatching the PR workflow:

```bash
gh pr view <number> --json headRefOid --jq .headRefOid
```

The example uses a `niro-autonomous` GitHub environment. Configure required
reviewers on that environment when you want an approval in addition to the
manual dispatch. Do not replace the example with an automatic
`pull_request_target` job that checks out PR code while exposing secrets.

The GitHub App credentials below are needed only for workflows that create fix
PRs (`niro-fix.yml`, `niro-fix-diff.yml`).

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

### GitLab Merge Requests

The supplied MR-scoped find job appears only in merge-request pipelines and is
`manual`. Start it after reviewing the selected revision. The job exposes
`GITLAB_TOKEN` and the selected model credential to autonomous execution, so
keep those variables masked, least-privilege, and unavailable to untrusted
forks. Before Niro starts, the job verifies the pipeline's source head against
the MR and checks out that commit; a stale manually started pipeline fails
instead of testing or marking the current MR head. Niro then verifies its
checkout against the live MR head and derives the base from that same forge
response. Standard and merged-result pipelines both test the MR source head;
for a merged-result pipeline the job replaces GitLab's temporary merge-commit
checkout with the source revision before Niro starts. Merge-train pipelines are
rejected because their temporary commit can contain other queued MRs. Do not
change the job to automatic execution for arbitrary MR content.

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

Copilot runs against any OpenAI-compatible model provider — OpenRouter,
Groq, Together, Fireworks, or a self-hosted gateway. Point it at the provider
of your choice with these variables; the example values use OpenRouter.

| Variable | Purpose | Example |
| --- | --- | --- |
| `COPILOT_PROVIDER_BASE_URL` | The provider's OpenAI-compatible API base URL. | `https://openrouter.ai/api/v1` |
| `COPILOT_PROVIDER_TYPE` | The API dialect — `openai` for OpenAI-compatible endpoints. | `openai` |
| `COPILOT_MODEL` | The model to use, in the provider's own naming. | `z-ai/glm-5.2` |

| Secret | Purpose |
| --- | --- |
| `COPILOT_PROVIDER_API_KEY` | API key for your chosen provider (e.g. an OpenRouter key). |

## Application Secrets

Pass the same secrets your application needs to boot and run tests in CI. These
are only needed when the Niro job starts the app or test harness locally. If
Niro is testing an already-running staging or production target, authorize that
target in Niro scope instead of copying those runtime secrets into CI.

For an existing staging target, expose only the secrets required by the
approved `harness/seed.sh` or `seed.ps1` preparation. That operation generates
the gitignored Niro credentials and fixtures used by the run. See
[Prepare your app](prepare-your-app.md#test-an-existing-staging-application).

These are your app's normal runtime secrets, not Niro credentials.

Examples include `DATABASE_URL`, `REDIS_URL`, `JWT_SECRET`, `NEXTAUTH_SECRET`,
payment provider test keys, cloud credentials, and test user credentials.

Manage these as CI secrets and expose them to the Niro job the same way you
would for your existing test job.
