# Prepare your app

Before a run, choose where the application runs, which agent CLI and Git provider
Niro uses, what it should test, and whether it should only report findings or
also prepare fixes.

## 1. Choose the application runtime

This is the first and most important decision.

| Choice | Choose it when | You do | Niro does |
| --- | --- | --- | --- |
| Use an existing runtime | The app already runs in staging, pre-production, or a dedicated test environment | Pass its exact URL, authorize the destination, and provide test access | Connects to the running app and creates permitted test state as needed |
| Let Niro start the app | You want to test the current checkout locally or in CI | Omit the URL and ensure the project has a working development path | Builds a repeatable harness, starts the app, seeds state, and resets it |

### Test an existing staging application

Set up a repeatable staging profile once:

1. Create a configuration directory for the environment:

   ```bash
   niro init --config-dir=niro-staging
   ```

2. Edit [`scope.yaml`](../examples/niro-config/scope.yaml) and authorize only
   the staging hosts and ports Niro may test.
3. Add `niro-staging/harness/seed.sh` on macOS/Linux or `seed.ps1` on Windows.
   It creates or resets dedicated test users, tenants, and resources through an
   application API, staging job, or existing seed tool. Add a matching `reset`
   script only when a run needs a separate clean-baseline operation.
4. Have that mechanism generate the gitignored `credentials.yaml` and
   `fixtures.yaml`. Commit the preparation code, not its environment-specific
   output.

Then every assessment is one command:

```bash
niro find --config-dir=niro-staging --url=https://staging.example.com
niro fix --config-dir=niro-staging --url=https://staging.example.com
```

`--url` is the runtime contract: its presence tells Niro to use that exact
existing runtime; its absence tells Niro to build and operate the current
checkout. It does not authorize the destination. The URL's host and port must
already be allowed by the selected `scope.yaml`.

Niro invokes the approved preparation as part of the run. Customers do not need
to recreate accounts, credentials, or fixtures before every assessment. The
committed preparation is the approval boundary: Niro runs it but does not rewrite
it while assessing an existing remote target. See the generated
[preparation contract](../examples/niro-config/harness/README.md),
[`credentials.yaml.example`](../examples/niro-config/credentials.yaml.example),
and [`fixtures.yaml.example`](../examples/niro-config/fixtures.yaml.example).

### Let Niro start the application

When Niro starts the app, it works with the project's existing Dockerfile,
Compose file, development command, factories, migrations, and seed helpers. See
the generated [harness contract](../examples/niro-config/harness/README.md) for
the exact `start`, `stop`, `seed`, and `reset` lifecycle.

This choice is separate from Docker or Podman. A container runtime is always
needed for Niro's isolated attack-tool sandbox; it does not determine where the
application itself runs.

## 2. Choose the agent CLI

| Choice | You do | Niro does |
| --- | --- | --- |
| Claude Code | Authenticate Claude; no flag is needed | Uses Claude by default |
| Codex | Authenticate Codex and pass `--agent=codex` | Runs through your Codex configuration |
| Copilot | Authenticate Copilot and pass `--agent=copilot` | Runs through your Copilot configuration |

Niro uses the agent CLI's existing provider account and does not proxy model
requests. See [Supported agents](supported-agents.md) for local and CI
authentication.

## 3. Choose the Git provider

Niro detects the Git provider from the repository remote.

| Choice | You do |
| --- | --- |
| GitHub | Authenticate `gh` |
| GitLab | Authenticate `glab` |
| Azure DevOps | Authenticate `az` |
| Find without pull requests | No write-enabled Git provider is required |

Git-provider authentication is required when Niro reads a pull request or merge
request, publishes status, or opens fixes. Niro never merges generated changes.

## 4. Choose what to test

| Scope | Customer action |
| --- | --- |
| Pull request or merge request | Pass `--pr-number 42` to `niro find` |
| Commit range | Pass `--base-sha <base> --head-sha <head>` |
| Focused goal | Pass `--goal "Test account recovery"` |
| Whole application | Omit the scope selector |

Run scope answers **what Niro should examine**. `scope.yaml` answers a different
question: **which network destinations Niro is authorized to reach**. A person
must authorize remote targets before testing. See
[Security and data](security-and-data.md) for the enforced boundary.

## 5. Choose the outcome

| Choice | Run | Result |
| --- | --- | --- |
| Find | `niro find` | Proven findings without fix branches or pull requests |
| Fix | `niro fix` | Fixes, validation evidence, and reviewable pull requests when Niro can safely remediate the bug |

## Put the choices together

Let Niro start the local app, test one workflow, and report findings:

```bash
niro find --goal "Test account recovery"
```

Test an existing authorized staging target and prepare fixes:

```bash
niro fix --config-dir=niro-staging --url=https://staging.example.com --goal "Test authentication"
```

Review a pull request using Codex:

```bash
niro find --agent=codex --pr-number 42
```

The generated [`niro/` configuration](../examples/niro-config/) contains the
exact setup reference for the installed Niro version. See
[Run Niro](run-niro.md) for CI workflows, runtime limits, and every execution
mode.
