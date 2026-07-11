# Run Niro

Run Niro from the root of the Git repository you want to test. Choose the
outcome you want, the application surface to test, and the agent to use. The
turnkey `find` and `fix` commands initialize Niro automatically.

## Choose an outcome

| Command | What it does | Code changes |
| --- | --- | --- |
| `niro find` | Pentests the selected scope and reports proven findings | Does not create branches, commits, or fix pull requests |
| `niro fix` | Pentests, prepares fixes and regression tests, and delivers reviewable changes | Can create branches, commits, pull requests, or patch artifacts; never merges |

Use `find` when you want evidence without remediation changes. Use `fix` when
you want Niro to carry confirmed findings through remediation and verification.

## Choose what to test

| Scope | Example | Use it for |
| --- | --- | --- |
| Whole application | `niro fix` | A complete assessment of the configured application |
| Focused goal | `niro fix --goal "Test account recovery"` | A feature, workflow, or security concern |
| Commit range | `niro fix --base-sha origin/main --head-sha HEAD` | Changes between two Git revisions |
| Pull request or merge request | `niro find --pr-number 42` | Reviewing an existing change without modifying its branch |

Scope selectors are mutually exclusive. A pull-request or merge-request scope
is report-only and is supported by `find`, not `fix`. Use a commit range with
`fix` when you want separate remediation changes for an existing diff.

A local command without a scope tests the whole application. Whole-application
runs can take a few hours; a goal, range, or pull-request scope is usually the
faster feedback loop.

## Choose an agent

Claude Code is the default. Select another installed agent per command:

```bash
niro find --agent=codex --goal "Test account recovery"
niro fix --agent=copilot --goal "Test account recovery"
```

| Agent | Flag |
| --- | --- |
| Claude Code | Omit `--agent` |
| OpenAI Codex | `--agent=codex` |
| GitHub Copilot CLI | `--agent=copilot` |

Agent authentication and model selection remain under that agent's normal
configuration. See [Supported agents](supported-agents.md) and
[Model selection](model-selection.md).

## Run locally

Start with a focused report-only run when you want to validate the application
setup and agent authentication before allowing remediation changes:

```bash
niro find --goal "Test authentication and session handling"
```

Run the same scope in fix mode when the Git provider is authenticated and you
are ready to review generated changes:

```bash
niro fix --goal "Test authentication and session handling"
```

`fix` requires a Git remote and an authenticated provider CLI. Niro uses your
existing `gh`, `glab`, or `az` authentication and never merges generated
changes.

Local runs keep their results in your environment. Depending on the outcome,
the workspace can contain `niro-summary.md`, `niro-knowledge.tar`, and optional
debug bundles. `fix` can also create remote branches and pull requests. See
[Review the results](review-results.md) for the review workflow.

To invoke Niro from inside an interactive agent session instead of using the
turnkey commands, follow [Run Niro from an interactive agent
session](supported-agents.md#run-niro-from-an-interactive-agent-session).

## Run in CI

CI uses the same `niro find` and `niro fix` commands as a local run. The runner
needs a container runtime, noninteractive agent authentication, the application
dependencies, and any Git-provider permissions required by the chosen outcome.

### GitHub Actions

| Trigger and scope | Find | Fix |
| --- | --- | --- |
| Manual whole-application run | [`niro-find.yml`](../examples/github-actions/niro-find.yml) | [`niro-fix.yml`](../examples/github-actions/niro-fix.yml) |
| Push or commit range | [`niro-find-diff.yml`](../examples/github-actions/niro-find-diff.yml) | [`niro-fix-diff.yml`](../examples/github-actions/niro-fix-diff.yml) |
| Pull request | [`niro-find-pr.yml`](../examples/github-actions/niro-find-pr.yml) | Use the find workflow |

Whole-application and range-based `find` runs publish their report to the job
summary. The pull-request workflow posts a comment and status using the
built-in `GITHUB_TOKEN`. `fix` needs GitHub App credentials because it pushes
branches and opens new pull requests.

### GitLab CI/CD

| Trigger and scope | Find | Fix |
| --- | --- | --- |
| Manual whole-application run | [`niro-find.yml`](../examples/gitlab-ci/niro-find.yml) | [`niro-fix.yml`](../examples/gitlab-ci/niro-fix.yml) |
| Push or commit range | [`niro-find-diff.yml`](../examples/gitlab-ci/niro-find-diff.yml) | [`niro-fix-diff.yml`](../examples/gitlab-ci/niro-fix-diff.yml) |
| Merge request | [`niro-find-pr.yml`](../examples/gitlab-ci/niro-find-pr.yml) | Use the find workflow |

GitLab `find` can report on merge requests, and `fix` opens review-ready merge
requests through `glab`.

The ready-to-copy templates cover GitHub Actions and GitLab CI/CD. You can run
the same CLI commands in another CI system and configure that workflow's
checkout, secrets, container runtime, and artifact publication directly.

See [CI environment](ci-environment.md) for agent secrets and provider-specific
environment variables.

## Control runtime and cost

Runtime and model cost depend on application size, setup, scope, model choice,
and concurrency. Configure limits in `niro/niro.yaml`:

```yaml
limits:
  max_budget_usd: 25
  max_duration_minutes: 120
  max_concurrency: 4
```

- `max_budget_usd` limits model spend for the run.
- `max_duration_minutes` limits total wall-clock time.
- `max_concurrency` controls how many test cases can execute concurrently.

A tight limit can stop a run before it reaches useful coverage. Prefer a
focused scope when you need a short run rather than applying an unrealistically
small whole-application budget.

## Stop a run

Interrupt the local command or cancel the CI job. Findings, branches, pull
requests, and artifacts already written remain available for review. If the
process was terminated before cleanup completed, remove any remaining Niro
container through Docker or Podman.

## Next steps

- [Prepare your app](prepare-your-app.md) for targets, scope, credentials, and
  test state.
- [Review the results](review-results.md) for findings, proofs, regression
  tests, and remediation changes.
- [CLI and configuration reference](cli-and-config-reference.md) for every
  command, flag, and configuration field.
- [Troubleshooting](troubleshooting.md) for startup failures and diagnostics.
