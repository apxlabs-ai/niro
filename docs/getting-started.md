# Get started

This guide takes you from installation to your first Niro run. Run the commands
from the root of the Git repository you want to test.

## What you need

| Requirement | Why Niro needs it | Quick check |
| --- | --- | --- |
| Docker or Podman | Runs the isolated attack sandbox | `docker info` or `podman info` |
| Claude Code, Codex, or Copilot CLI | Runs the developer and attacker agents | `claude --version`, `codex --version`, or `copilot --version` |
| Git | Reads the repository and prepares fixes | `git rev-parse --show-toplevel` |
| Git provider CLI | Opens fix pull requests | `gh auth status`, `glab auth status`, or `az account show` |

You need only one container runtime, one supported agent, and the CLI for your
Git provider. Git-provider authentication is required for `fix`; a local,
goal-based `find` run can be used before you connect a Git provider.

See [Prerequisites](prerequisites.md) for installation links and platform notes.

## Install Niro

macOS or Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh | sh
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.ps1 | iex
```

Verify the installation:

```bash
niro version
```

## Choose an agent

Niro uses the agent you already have installed and authenticated.

| Agent | Select it |
| --- | --- |
| Claude Code | Default; omit `--agent` |
| OpenAI Codex | `--agent=codex` |
| GitHub Copilot CLI | `--agent=copilot` |

Start the selected agent once and complete its normal sign-in flow. Niro does
not have a separate login and does not proxy model requests. See
[Supported agents](supported-agents.md) for local and CI authentication.

## Run Niro

For a focused first run that tests the complete pentest-to-fix workflow:

```bash
niro fix --goal "Test the login and session flows"
```

Use your selected agent when Claude Code is not the default:

```bash
niro fix --agent=codex --goal "Test the login and session flows"
niro fix --agent=copilot --goal "Test the login and session flows"
```

Niro initializes the project automatically. You do not need to run `niro init`
before `niro find` or `niro fix`.

Use a report-only run when you do not want Niro to create fix branches or pull
requests:

```bash
niro find --goal "Test the login and session flows"
```

Omit `--goal` to test the whole application:

```bash
niro fix
```

### Test a change

```bash
# Review an existing pull request without changing it
niro find --pr-number 42

# Test a commit range and open separate fix pull requests
niro fix --base-sha origin/main --head-sha HEAD
```

Pull-request runs are report-only. Use a commit range with `fix` when you want
Niro to prepare separate fix pull requests.

A whole-application run can take a few hours. Focused goals and commit-range
runs are useful when you want faster feedback. See [Run Niro](run-niro.md) for
all scopes and execution modes.

## What the first run does

1. Initializes Niro's project configuration under `niro/`.
2. Detects Docker or Podman and starts the isolated attack sandbox.
3. Uses the selected agent to bring up or connect to the application and create
   the test state it needs.
4. Tests authorized application surfaces and proves exploitable findings.
5. In `fix` mode, prepares fixes and regression tests and opens reviewable pull
   requests for changes it can safely make.

Niro never merges generated changes.

## What success looks like

A completed run prints where it placed the results.

- `find` reports proven findings without creating fix branches or pull
  requests.
- `fix` opens pull requests for confirmed findings it can safely fix. A clean
  run or a finding without a safe automated fix may produce no pull request.
- Local summaries, findings, logs, and knowledge bundles remain in your
  workspace or Niro cache unless you configure a workflow to publish them.

Review every finding, exploit proof, regression test, and code change before
accepting it.

## If the run cannot start

Check the four dependencies independently:

```bash
docker info || podman info
claude --version   # or codex / copilot
git rev-parse --show-toplevel
gh auth status     # or glab auth status / az account show
```

If the agent command exists but cannot make a model request, open that agent
directly and complete its sign-in flow. If `fix` can test the app but cannot
open a pull request, verify the repository remote and Git-provider login, or run
`find` while you correct the Git permissions.

## Next steps

- [Prepare your app](prepare-your-app.md) for scope, targets, credentials, and
  test state.
- [Run Niro](run-niro.md) for whole-app, focused, commit-range, pull-request,
  and CI runs.
- [Supported agents](supported-agents.md) for provider authentication and model
  configuration.
- [Security and data](security-and-data.md) for the data-flow diagram and
  security FAQ.
