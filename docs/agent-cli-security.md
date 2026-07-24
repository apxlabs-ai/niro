# Agent CLI privileges and threat model

This is the security contract for turnkey `niro find` and `niro fix` runs. Read
it before using `--autonomous` or running Niro in CI.

The selected agent CLI runs on the host. Interactive mode uses that CLI's
native permission UI. `--autonomous` removes its approval prompts and grants it
the full authority of the OS user running Niro.

## Trust boundary

Niro uses four terms:

- **agent CLI** — the customer-installed `claude`, `codex`, or `copilot`
  executable Niro invokes;
- **developer agent** — the host-side role that requests pentests and prepares
  code changes;
- **attacker agent** — the host-side reasoning role that finds and proves
  vulnerabilities; and
- **attack-tool sandbox** — the Docker or Podman container where target-facing
  command-line and browser tools execute.

The developer agent and attacker agent both reason on the workstation or CI
runner through the agent CLI. Neither runs in the attack-tool sandbox. That
sandbox contains attack tools; it does not contain the agent CLI, application
setup, Git, or other host commands.

`scope.yaml` restricts normal traffic from the attack-tool sandbox. It is not a
host firewall and does not restrict the agent CLI's network access.

## Execution modes

| Mode | Permission contract | Use it for |
| --- | --- | --- |
| Interactive (default) | The agent CLI applies its configured sandbox and approval policy and shows its native UI | Attended local work where a person can inspect requests |
| Autonomous (`--autonomous`) | Agent CLI approval prompts are disabled; commands run with full current-user host access | Reviewed revisions on isolated, ephemeral, least-privilege runners |

Niro refuses interactive execution in CI or without attached input and output
terminals. It never infers autonomous authority from repository configuration
or CI detection; the caller must pass `--autonomous`.

Interactive mode does not promise a prompt for every read, command, or network
request. The agent CLI decides what to prompt for based on its version,
configuration, policy, and earlier approvals. Niro adds no second host sandbox.

### Provider policy

| Agent CLI | Interactive | Autonomous |
| --- | --- | --- |
| Claude Code | `claude --permission-mode default <goal>` | `claude --print --dangerously-skip-permissions <goal>` |
| OpenAI Codex | `codex --ask-for-approval on-request -c features.apps=false <goal>` | `codex exec --dangerously-bypass-approvals-and-sandbox -c features.apps=false <goal>` |
| GitHub Copilot CLI | `copilot --interactive <goal>` | Copilot SDK with `OnPermissionRequest: ApproveAll` and workspace configuration discovery enabled |

Codex autonomous runs can therefore report `approval: never` and `sandbox:
danger-full-access`. That is expected only after the caller explicitly passes
`--autonomous`.

## Host boundary

### Installation, files, and commands

Before a run, Niro checks whether the selected agent CLI is on `PATH`. If it is
missing, Niro runs `npm install -g` for that CLI's package. This occurs before
the agent CLI opens in either execution mode and can contact the npm registry
and modify the configured global npm prefix. Install the CLI yourself first if
you do not want Niro to do this.

The agent CLI starts in the current checkout. Niro does not create a clean
clone, disposable worktree, container, VM, or separate OS account for it. With
autonomous authority, it and its subprocesses can:

- read or modify any file available to the current user, including files
  outside the repository and uncommitted work;
- read user-accessible credential files and CLI login caches;
- install dependencies, run package lifecycle scripts, build or test the
  application, and start or stop processes; and
- reuse the user's Docker, Podman, Git, cloud, package-manager, and other
  authority.

Interactive mode can reach the same resources when the agent CLI policy allows
it or the person approves it.

### Environment and credentials

The agent CLI inherits nearly all of Niro's environment, including application,
model-provider, and Git credentials placed in the process or CI job. Niro makes
only these narrow transformations:

- it removes `CODEX_AUTH_JSON_B64` after restoring the Codex login file; and
- it adds or replaces its own orchestration variables.

Every other variable is passed through unchanged and is available to the agent
CLI and its child processes—including all model-provider and BYOK keys, Git
tokens, and application secrets. This is not a secret allowlist, and Niro does
not isolate credentials from the agent. Assume that any credential present in
the run's environment can be read by the agent, printed into model context, or
exfiltrated by untrusted repository content or prompt injection, and can reach
the model provider or another network destination. Give a run only the
credentials it needs: prefer least-privilege, short-lived, dedicated
credentials—especially in CI, where the environment usually holds higher-value
shared secrets—and rotate anything you would not want disclosed.

### Host network egress

Niro does not filter egress from the agent CLI or its host subprocesses. They
can reach anything allowed by the workstation, runner, VM, or container network
policy—not just the model provider, Git provider, registries, and test target.

The attack-tool sandbox separately applies default-deny egress and permits
normal pentest traffic only to targets authorized by `scope.yaml`. That policy
does not restrict the developer agent or attacker agent.

### Repository and target prompt injection

Repository and target content is untrusted input to the model. Depending on its
configuration, the agent CLI can discover `AGENTS.md`, `CLAUDE.md`, skills,
plugins, MCP configuration, hooks, build scripts, and package lifecycle
scripts. Copilot autonomous mode explicitly enables workspace configuration
discovery. Source, issue or PR text, dependency and test output, and application
responses can also contain hostile instructions.

Niro does not sanitize these inputs or claim to detect semantic prompt
injection. Interactive approvals can stop a requested command, but they do not
prevent the model from reading content, sending context to its provider, or
presenting a misleading request.

Never run autonomous Niro automatically on an unreviewed pull-request or
merge-request revision with secrets. The supplied PR and MR examples require a
human to start the job, check out the reviewed source head, and fail if the
change moves. Niro binds the autonomous run to that checkout, captures the base
and head together, and excludes mutable PR/MR title and description text. The
reviewed source and diff remain untrusted model input.

## `find` and `fix` are outcomes, not privilege levels

| Command | Requested outcome | Host-side reality |
| --- | --- | --- |
| `niro find` | Report findings; do not create fix branches, commits, or PRs | It can initialize Niro state, prepare or start the app, install dependencies, and write reports or artifacts. It is not an OS-level read-only mode. |
| `niro fix` | Prepare fixes, evidence, commits, and review-ready PRs or MRs | It intentionally permits repository and Git changes, but never merges them. |

Execution mode controls host authority; the command controls the requested
outcome.

## Operating guidance

For an attended local run:

1. Use a clean working tree or back up uncommitted work.
2. Run as a non-administrative user and remove unrelated secrets from the
   environment.
3. Use a staging target and least-privilege test accounts.
4. Inspect permission requests and deny paths or commands outside the run.

For an autonomous run:

1. Use an ephemeral runner, VM, or container with a disposable checkout.
2. Use a dedicated or rootless Docker or Podman runtime; do not connect the job
   to a shared production daemon.
3. Expose only short-lived, repository-scoped credentials required by the run.
4. Restrict egress at the runner, VM, or container boundary.
5. Run an immutable revision reviewed for autonomous execution.
6. Keep branch protection and human review between generated changes and merge.

Niro Community Edition does not enforce this host deployment profile. The
operator owns that boundary.

## Related documentation

- [Security and data](security-and-data.md) — data destinations, attack-tool
  sandbox scope, telemetry, and retention.
- [Run Niro](run-niro.md) — execution, scope, runtime, and outcomes.
- [Supported agent CLIs](supported-agents.md) — installation and
  authentication.
- [CI environment](ci-environment.md) — credentials exposed to CI runs.
