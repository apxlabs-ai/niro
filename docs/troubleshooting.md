# Troubleshooting

Start with the first failing boundary. Do not widen `scope.yaml`, add privileged
credentials, disable a security control, or switch to production merely to make
a run proceed.

Preserve these three items before changing the setup:

1. The exact `niro` command, with secret values removed.
2. The first actionable error, not only the final exit line.
3. The selected config directory, runtime choice, and agent CLI.

## Check the local dependencies

Run the checks that apply to the selected workflow:

```bash
niro version
docker info || podman info
claude --version        # or: codex --version / copilot --version
git rev-parse --show-toplevel
git remote get-url origin
gh auth status          # or: glab auth status / az account show
```

Windows PowerShell:

```powershell
niro version
docker info             # or: podman info
codex --version         # or: claude --version / copilot --version
git rev-parse --show-toplevel
git remote get-url origin
az account show         # or: gh auth status / glab auth status
```

Interpret failures in order:

| Failed check | Fix before retrying |
| --- | --- |
| `niro version` | Install Niro or correct the shell `PATH` |
| Container runtime | Start Docker or Podman and confirm the current user can access it |
| Agent CLI version | Install the selected agent CLI or select the installed one with `--agent` |
| Git repository | Run from the intended repository root |
| Git remote | Add or correct `origin`; Niro uses it to detect the Git provider |
| Git-provider authentication | Sign in with the matching CLI before using PR, MR, or fix workflows |

For a report-only directed run, Git-provider write authentication is not
required. The container runtime and selected agent CLI are always required.

## The Niro command is not found

Confirm the installation and shell path:

```bash
command -v niro
niro version
```

Windows PowerShell:

```powershell
Get-Command niro -All
niro version
```

Open a new shell after installation if the installer updated a profile file.
On macOS or Linux, run `type -a niro` to list multiple binaries. On Windows,
use `Get-Command niro -All`. Remove stale path entries rather than mixing
versions across runs.

## Docker or Podman is unavailable

Typical errors include `no runtime found on PATH`, daemon connection failures,
or permission-denied responses.

1. Run `docker info` or `podman info`, not only the version command.
2. Start the runtime daemon or desktop application.
3. Confirm the current user can create containers.
4. If both runtimes are installed, pin the working one in `niro.yaml`:

   ```yaml
   container:
     runtime: docker
   ```

5. Retry the same focused command.

If the attack-tool sandbox starts and then exits, use the diagnostic text Niro
prints first. It includes bounded container inspect and log output when startup
fails.

## The selected agent CLI is missing or cannot authenticate

Match the flag to the installed CLI:

```bash
niro find --agent=codex --goal "Test login"
```

Start that agent CLI directly and complete its normal sign-in flow. A version
check proves only that the executable exists; make one normal model request in
the agent CLI to verify provider access, billing, and the selected model.

In CI, interactive login is not available. Check that the selected agent CLI's
secret is present in the same job that runs Niro and that masked variables are
not restricted from the current branch or environment. See
[Supported agents](supported-agents.md#authenticate-in-ci).

If a pinned model is rejected, remove the corresponding `models.high`,
`models.medium`, or `models.low` override and let Niro select the default. An
explicit model identifier is passed to the agent CLI exactly as written.

## The selected agent CLI is too old for the chosen model

The error reports the installed agent CLI version and the minimum required by
the effective native model. Upgrade the selected agent CLI through its
provider-supported update flow, then confirm the new version before retrying:

```bash
claude --version        # or: codex --version / copilot --version
```

If an immediate upgrade is not possible, pin the tier to an older model that
the installed agent CLI supports. Single-session commands such as draft and
triage validate only the tier they launch; a pentest can use all three tiers,
so each configured pentest tier must be compatible. Model overrides are exact
identifiers—see [Model selection](model-selection.md) before changing one.

## Configuration cannot be loaded

Niro rejects unknown YAML keys, invalid values, and unsupported schema versions.
Read the full error; it names the field and accepted constraint.

Common corrections:

- run `niro upgrade` when the project configuration requires a newer CLI;
- fix the misspelled field instead of deleting strict validation;
- keep `max_test_case_duration_minutes` no greater than
  `max_duration_minutes`;
- keep `--config-dir` relative to the repository root; and
- use a separate config directory for each environment.

Compare fields against [CLI and configuration
reference](cli-and-config-reference.md#niroyaml) and the generated
[`niro.yaml`](../examples/niro-config/niro.yaml).

`niro init` never overwrites existing files. Re-running it is safe, but it will
not replace an older customized file with a new template.

## The target URL is rejected

`--url` must be an absolute HTTP or HTTPS URL. It cannot contain embedded
credentials or a fragment.

```bash
niro find \
  --config-dir=niro-staging \
  --url=https://staging.example.com \
  --goal "Test authentication"
```

The URL selects an existing runtime. It does not authorize the destination.
Confirm that the selected `scope.yaml` allows the URL's exact host and effective
port. HTTPS defaults to `443`; HTTP defaults to `80`.

Do not put URL paths in `scope.yaml`. Scope authorizes network destinations,
not application routes.

## The sandbox reports an out-of-scope destination

Treat the block as a security decision, not a connectivity error.

1. Identify which application action attempted the connection.
2. Confirm the destination is customer-owned and approved for testing.
3. Add only the required host or CIDR and ports to the selected `scope.yaml`.
4. Keep third-party analytics, payment, messaging, and production systems
   excluded unless testing them is explicitly authorized.
5. Rerun the same scope.

When the application has many legitimate dependencies, use `niro draft scope`
to produce a proposal. Review it before replacing `scope.yaml`; Niro never
authorizes the draft automatically.

## The application is healthy on the host but unreachable to Niro

A host-side browser or `curl` result does not prove the attack-tool sandbox can
reach the application.

Check these boundaries:

- the application is listening on the expected port and not only on an
  unrelated interface;
- `--url` names the same runtime authorized by the selected profile;
- the effective host and port appear in `scope.yaml`;
- a local harness reports health only after the full service graph is ready;
- VPN, proxy, DNS, and firewall policy permit the container runtime to reach a
  remote private target; and
- TLS trust and hostname validation match the target URL.

Niro maps `localhost` and `127.0.0.1` so a locally running application remains
reachable from its container. Keep using the real local URL rather than
hard-coding a container-runtime-specific gateway name.

## Existing-runtime preparation fails

With `--url`, Niro does not start, stop, rebuild, or redeploy the application.
It can invoke only the committed `seed` and optional `reset` preparation for
that profile.

Verify that:

- the script for the runner platform exists (`seed.sh` or `seed.ps1`);
- it is executable and noninteractive;
- it is idempotent and limited to dedicated test state;
- required secret-manager or application variables are available;
- it writes `credentials.yaml` and `fixtures.yaml` into the selected config
  directory; and
- a failed lookup exits nonzero instead of emitting empty or stale values.

Run the approved preparation independently when necessary, but do not print its
generated credentials into logs or a support issue. See the generated
[preparation contract](../examples/niro-config/harness/README.md).

## Authentication tests are blocked

The most common cause is insufficient test identity context.

Provide:

- two distinct users with separately owned resources for each horizontal
  authorization boundary;
- a lower-privilege and higher-privilege identity for each role boundary;
- separate tenants or organizations where tenant isolation matters; and
- accurate descriptions of effective permissions, including capabilities that
  do not follow from a role name.

Generate raw values into the gitignored `credentials.yaml`. Put non-secret
resource IDs and other reference points in `fixtures.yaml`. Do not add a
production administrator credential merely to unblock a staging test.

## The run stops on time, budget, or provider limits

First narrow the work with `--goal`, a commit range, or a pull-request scope.
Then adjust the relevant limit in `niro.yaml` if broader coverage is still
required.

For provider throttling, lower concurrency:

```yaml
limits:
  max_concurrency: 1
```

For a test case that legitimately needs more time, raise
`max_test_case_duration_minutes` without exceeding the total run duration. A
run stopped by a limit is partial coverage; review its blocked cases before
interpreting the result.

## A pull-request or merge-request run cannot read the change

Confirm all of the following:

- `origin` points to the expected GitHub or GitLab repository;
- `--pr-number` is the GitHub PR number or GitLab MR IID;
- for an autonomous PR/MR run, the checkout's `HEAD` is the current PR/MR head
  (the supplied workflows check out and verify it automatically);
- `gh auth status` or `glab auth status` succeeds for that host;
- the authenticated identity can read the private repository and change; and
- the checkout contains the repository metadata Niro needs.

Pull-request and merge-request mode is supported by `niro find`, not
`niro fix`. Use a commit range with `fix` when remediation changes are required.
If Niro reports that the checked-out head does not match the current change,
review the new revision and start a new workflow run rather than reusing the
stale one.

## A fix run does not open a pull request

A completed run can legitimately produce no fix change. Check
`niro-summary.md` before treating this as a Git failure.

Possible outcomes include:

- no exploitable finding was proven;
- the finding requires a product, deployment, infrastructure, or third-party
  decision rather than a safe repository change;
- the run stopped before remediation;
- the selected Git provider could not be authenticated; or
- Niro produced a local patch fallback instead of a remote pull request.

For an authentication failure, verify the provider CLI and repository remote.
GitHub CI fix workflows also require the configured GitHub App credentials;
GitLab fix workflows require a token able to write the repository and open
merge requests. Niro never merges generated changes.

## A CI run has no visible result

Check the workflow in this order:

1. Read the Niro command's exit text and the CI job log.
2. Confirm the artifact upload step uses `if: always()` or the provider
   equivalent.
3. Look for `niro-summary.md` and `niro-knowledge.tar`.
4. Confirm the selected agent CLI secret was available to the job.
5. Confirm the runner offers a working container runtime.
6. Confirm the workflow supplied an explicit goal or revision scope.

Use the maintained [GitHub Actions and GitLab CI/CD
examples](run-niro.md#run-in-ci) as the baseline. Keep debug-log publication
disabled unless actively diagnosing a failure.

## Inspect local logs

Niro writes JSON-lines logs under the operating-system cache directory:

| Platform | Log directory |
| --- | --- |
| macOS | `~/Library/Caches/niro/logs` |
| Linux | `~/.cache/niro/logs` |
| Windows | `%LocalAppData%\niro\logs` |

The primary files are:

| File | Contents |
| --- | --- |
| `niro-cli.jsonl` | Host CLI, agent CLI launch, and subprocess activity |
| `niro-agent.jsonl` | Attack-tool service and tool activity inside the sandbox |
| `niro-security.jsonl` | Environment authorization, DNS, scope, and firewall decisions |

Filter one run by its `pentest_id` when `jq` is available:

```bash
jq -c 'select(.pentest_id == "<pentest-id>")' \
  ~/Library/Caches/niro/logs/niro-security.jsonl
```

Set `log_level: debug` only for a deliberate diagnostic run. Security-boundary
records remain available regardless of the operational log level.

## Create a debug bundle intentionally

Rerun the smallest reproducing scope with debug-log bundling enabled:

```bash
niro find --goal "Test login" --upload-debug-logs
```

This can create `niro-debug-logs.tar`. Debug logs can contain command output,
application responses, paths, and other sensitive operational data. Inspect
and redact the archive before sharing it. Finding proofs in
`niro-knowledge.tar` are also sensitive and should not be attached to a public
issue.

## Ask for help

Open a [GitHub issue](https://github.com/apxlabs-ai/niro/issues) with the Niro
version, operating system, selected runtime and agent CLI, sanitized command,
and first actionable error. Do not include credentials, target URLs, private
source, finding proofs, or unreviewed debug bundles.

For security architecture, data handling, or due-diligence questions, contact
[security@apxlabs.ai](mailto:security@apxlabs.ai).
