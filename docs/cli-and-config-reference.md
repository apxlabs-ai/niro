# CLI and configuration reference

Run Niro from the root of the Git repository being tested. The command name
comes first, followed by that command's scope and flags.

```bash
niro <command> [scope] [flags]
```

Use `niro <command> --help` to inspect the syntax supported by the installed
version. This page documents the customer-facing commands. Commands shown only
by `niro --help --all` are invoked by Niro or an integrated developer agent and
should not be used as workflow entry points.

## Commands

| Command | Purpose |
| --- | --- |
| `niro init` | Scaffold Niro configuration and agent CLI integration in a repository |
| `niro find` | Pentest and report proven findings without creating fix changes |
| `niro fix` | Pentest and open review-ready fixes for proven findings |
| `niro draft scope` | Explore a running application and write a scope proposal |
| `niro triage` | Decide whether a pull-request diff requires a runtime pentest |
| `niro upgrade` | Replace the CLI with the latest released version |
| `niro uninstall` | Remove the CLI and optionally its cached attack-tool image |
| `niro version` | Print the installed version and build information |

## Initialize a project

```bash
niro init [<project-dir>] [flags]
```

| Flag | Value | Default | Effect |
| --- | --- | --- | --- |
| `--agent` | `claude`, `codex`, or `copilot` | All supported agent CLIs | Install integration files only for the selected agent CLI |
| `--config-dir` | Repository-relative path | `niro` | Create a separate environment profile such as `niro-staging` |
| `--quiet` | Boolean | `false` | Print only the result and warnings; useful in automation |

Each agent CLI's hook config is installed automatically (`.claude/settings.json`,
`.codex/hooks.json`, `.github/hooks/niro.json`). The hooks feed Niro's run ledger —
a silent record of each session's tool calls and lifecycle — so `niro` must be on
your `PATH` for them to fire.

Initialization never discards your own content. Files it fully owns are reported
as skipped when already present. For a valid existing `.mcp.json`, Niro adds only
the `mcpServers.niro` entry and preserves every other setting and server. It
fails without rewriting malformed or structurally incompatible JSON. A re-run
can also add lifecycle hooks a prior init was missing: Niro merges its own
entries into an existing `.claude/settings.json` or `.codex/hooks.json`
(preserving your other settings and hooks), and refreshes the Niro-owned
`.github/hooks/niro.json` for Copilot. Re-running once everything is current
reports skipped. `niro find` and `niro fix` initialize the default project
automatically when Niro will start the application. Initialize explicitly when
you need an alternate profile or will test an existing runtime with `--url`.

## Find and fix

```bash
niro find [scope] [flags]
niro fix [scope] [flags]
```

### Scope selectors

Use at most one scope mode.

| Mode | Flags | Supported by | Meaning |
| --- | --- | --- | --- |
| Whole application (local) | None | `find`, `fix` | Test the configured application broadly outside CI |
| Focused goal | `--goal=<text>` | `find`, `fix` | Test the feature, workflow, or concern described in plain English |
| Commit range | `--base-sha=<base> --head-sha=<head>` | `find`, `fix` | Test behavior related to the selected Git range |
| Pull request or merge request | `--pr-number=<number>` | `find` | Review an existing change without modifying its branch |

`--base-sha` and `--head-sha` must be supplied together. Scope modes are
mutually exclusive. Outside CI, a command with no selector runs a
whole-application test. GitHub Actions and GitLab CI reject a command with no
selector; CI must provide an explicit goal, commit range, or pull-request or
merge-request scope and must pass `--autonomous`.

For an autonomous pull-request or merge-request run, Niro reads the checked-out
Git `HEAD` and verifies that it is still the change's current head. It captures
the base and head together from that forge response, diffs those commits,
excludes mutable PR/MR title and description text from the attacker agent's
artifacts, and posts commit statuses to the captured head. The caller supplies
only `--pr-number`; use the ready-to-copy CI workflows to check out a reviewed
source head safely.

### Common flags

| Flag | Default | Effect |
| --- | --- | --- |
| `--agent=claude|codex|copilot` | `claude` | Select the installed agent CLI for this command |
| `--autonomous` | `false` | Grant full current-user host access without agent CLI approval prompts; required in CI and other non-interactive environments |
| `--resume=<session-id>` | None | Continue a prior run's niro session instead of starting cold. Use the id printed after an autonomous run (`--resume <id> added`), resume with the same `--agent`, and re-run the original command so its scope (`--pr-number`, a SHA range, or `--goal`) is preserved |
| `--config-dir=<dir>` | `niro` | Select the repository-relative environment profile |
| `--url=<absolute-url>` | None | Use this existing HTTP or HTTPS runtime; without it Niro starts the current checkout |
| `--include-findings[=true|false]` | `true` | Include finding proof bundles in the published knowledge artifact |
| `--generate-report[=true|false]` | `true` | Generate one customer PDF from the final canonical pentest state |
| `--upload-debug-logs[=true|false]` | `false` | Create a sensitive debug-log bundle for intentional diagnostics |

An existing-runtime URL must be absolute, use HTTP or HTTPS, and match a host
and port authorized by the selected `scope.yaml`. It selects the runtime but
does not authorize it.

Without `--autonomous`, Niro launches the selected agent CLI's interactive
terminal interface and automatically submits the first message. If CI is
detected or stdin/stdout are not terminals, Niro exits before orchestration
rather than granting unattended authority implicitly. See [Agent CLI
privileges and threat model](agent-cli-security.md) for filesystem, process,
environment, egress, and repository-instruction boundaries.

`niro find` never creates fix branches, commits, or pull requests. `niro fix`
can create those changes but never merges them.

`niro find` and `niro fix` generate the PDF by default; pass
`--generate-report=false` to opt out. The PDF
is written into the Niro-owned, gitignored `<config-dir>/artifacts/` directory. A
local run prints its absolute path as `niro: report: <path>`; in CI the report is
delivered as an uploaded artifact instead. Niro generates it only after
the developer agent has reconciled the final agreed finding set: findings
covered by accepted behavior are deleted and disputes are finished. Creating or
verifying a fix does not remove an agreed finding from the report. In `fix`,
deletion of verified fixes is deferred until the PDF succeeds, then completed
before cleanup. The command fails when an enabled PDF is not produced or is
invalid.

## Draft network scope

```bash
niro draft scope <url> [flags]
```

| Flag | Default | Effect |
| --- | --- | --- |
| `--agent=<name>` | `claude` | Select the agent CLI used to explore the application |
| `--output=<path>` | `<config-dir>/scope.draft.yaml` | Select the proposal output path |
| `--timeout=<duration>` | `10m` | Stop exploration after the duration and write any partial draft |
| `--config-dir=<path>` | `<project-root>/niro` | Select the environment profile |
| `--project-root=<path>` | Current directory | Select the application source root |

Scope discovery writes a proposal, never an authorization file. Review every
destination, remove anything you do not own, then rename the approved file to
`scope.yaml`.

## Triage a pull request

```bash
niro triage --repo=<owner/repo> --pr-number=<number> [flags]
```

Triage inspects the diff without provisioning an application runtime and
prints one JSON report. If `pentest_required` is `true`, run `niro find` for the
same pull request.

| Flag | Required | Default | Effect |
| --- | --- | --- | --- |
| `--repo=<owner/repo>` | Yes | None | Identify the repository for CI and audit context |
| `--pr-number=<number>` | Yes | None | Select the pull request to screen |
| `--agent=<name>` | No | `claude` | Select the agent CLI used for triage |
| `--project-root=<path>` | No | Current directory | Select the checked-out source |
| `--config-dir=<path>` | No | `<project-root>/niro` | Select the Niro profile |
| `--timeout=<duration>` | No | Agent CLI default | Limit triage wall-clock time |

Triage exit codes are stable for automation:

| Code | Meaning |
| --- | --- |
| `0` | A usable JSON report was written, including reports with `ok:false` |
| `1` | Niro could not write a JSON report |
| `2` | Command usage was invalid; only stderr was written |
| `130` | The process was interrupted before a report was written |

## CLI lifecycle

```bash
niro version
niro upgrade
niro upgrade --yes
niro uninstall
niro uninstall --with-image --yes
```

`--yes` skips the confirmation prompt. `--with-image` also removes the cached
attack-tool image; a later installation can download it again.

## Configuration directory

The default configuration directory is `niro/`. Use a separate directory for
each environment and select it with `--config-dir`.

| Path | Purpose | Commit? |
| --- | --- | --- |
| `niro.yaml` | Project limits, models, Git publishing, logging, telemetry, and sandbox settings | Yes |
| `scope.yaml` | Authorized network destinations | Yes |
| `harness/` | Approved application lifecycle or existing-runtime preparation | Yes |
| `credentials.yaml` | Generated target credentials | No |
| `fixtures.yaml` | Generated environment-specific test references | No |
| `accepted-behaviors.yaml` | Reviewed behavior intentionally treated as accepted | Yes |
| `accepted-coverage-gaps.yaml` | Reviewed environment limitations | Yes |
| `findings/` | Local exploit proofs | No |
| `harness/run/` | Mutable application runtime state | No |
| `artifacts/` | Latest terminal run manifest, summary, report, and generated bundles | No |

Configuration directories must remain inside the repository and may contain
letters, digits, `.`, `_`, `-`, and `/`. Niro adds credentials, fixtures,
findings, harness runtime state, and terminal artifacts to `.gitignore`.

## `niro.yaml`

All keys are optional except the generated schema `version`. Omitted keys use
the defaults below. Unknown keys are rejected so a misspelling cannot silently
change the run.

| Field | Default | Valid values or constraint | Effect |
| --- | --- | --- | --- |
| `version` | `1` | Schema version supported by the installed CLI | Rejects incompatible configuration versions |
| `container.runtime` | `auto` | `auto`, `docker`, `podman` | Selects the attack-tool sandbox runtime; auto checks Docker then Podman |
| `container.max_memory` | `512m` | Runtime memory string such as `512m` or `2g` | Caps attack-tool container memory |
| `container.max_cpu` | `2` | `0.1` through `32` | Caps attack-tool container CPU |
| `container.idle_timeout_minutes` | `240` | Integer greater than `0` | Stops an abandoned idle attack-tool container |
| `limits.max_duration_minutes` | `180` | Integer at least `15` | Caps total run wall-clock time |
| `limits.max_concurrency` | `6` | Integer from `1` through `16` | Caps concurrent test cases |
| `limits.max_test_case_duration_minutes` | `15` | Integer at least `1` and no greater than total duration | Blocks an individual test case that exceeds its limit while allowing others to continue |
| `models.high` | Agent CLI default | Non-empty model identifier | Pins the attacker agent's strongest reasoning tier |
| `models.medium` | Agent CLI default | Non-empty model identifier | Pins the attacker agent's balanced reasoning tier |
| `models.low` | Agent CLI default | Non-empty model identifier | Pins the attacker agent's lightweight reasoning tier |
| `git_provider.kind` | `auto` | `auto`, `github`, `gitlab`, `azure-devops` | Selects or overrides Git-provider detection |
| `git_provider.publish` | `true` | Boolean | Enables comments and statuses; `false` retains authenticated reads but writes nothing back |
| `min_severity` | `medium` | `critical`, `high`, `medium`, `low` | Skips testing and reporting below the selected floor |
| `log_level` | `info` | `debug`, `info`, `warn`, `error` | Controls operational log verbosity; security-boundary logging remains enabled |
| `telemetry` | `true` | Boolean | Enables or disables the pseudonymous run event for this project |
| `headless` | `false` | Boolean | Allows automation to continue while surfacing concerns that would require acknowledgement in an interactive run |
| `security.env.access` | Empty | Unique POSIX names matching `[A-Z_][A-Z0-9_]*` | Authorizes additional host environment variables beyond known agent CLI settings |

Model identifiers are passed through exactly as written. Omit a model field to
let Niro choose a compatible default for the selected agent CLI and authentication
path. See [Model selection](model-selection.md).

`git_provider.publish: false` disables comments and statuses, not authenticated
reads. Remove any required Niro status from branch protection before disabling
publishing, or the status can remain pending.

## `scope.yaml`

`scope.yaml` is a default-deny network allowlist for normal attack execution.

```yaml
targets:
  - target: "app.staging.example.com:443"
  - target: "api.staging.example.com:443,8443"
  - target: "*.internal.example.com:8000-8999"
  - target: "10.0.42.0/24:443"
  - target: "billing.internal.example.com:443"
    excluded: true
```

| Field | Required | Meaning |
| --- | --- | --- |
| `targets` | Yes | Non-empty list of authorized or excluded network destinations |
| `targets[].target` | Yes | Exact host, leftmost-label wildcard host, IPv4 or IPv6 CIDR, plus required port specification |
| `targets[].type` | No | `address`; omit it for the default |
| `targets[].excluded` | No | When `true`, deny this destination even if another entry allows it |
| `allow_email_access` | No | Allow access to Niro's email test integration without making it a pentest target |

Ports can be single values, comma-separated values, ranges, or a combination.
Use brackets around IPv6 CIDRs. Scope does not support URL paths, and a wildcard
applies only to the leftmost DNS label. A bare `*` label also matches the apex:
`*.internal.example.com` authorizes both `internal.example.com` and one-label
subdomains such as `api.internal.example.com`, but not deeper names such as
`v1.api.internal.example.com`. Add an explicit exclusion for the apex when it
must remain out of scope. Constrained globs such as `api*.internal.example.com`
do not match the apex. Explicit exclusions take precedence.

## Credentials and fixtures

The approved harness should generate these files for each run.

### `credentials.yaml`

The top-level key is `credentials`. Every entry requires a unique
`credential_id`, `description`, and `type`. `credential_id` must match
`^[A-Z][A-Z0-9_]{0,63}$`. Keep the ID stable when rotating a value or editing
its description.

Supported types and additional fields are:

| Type | Required fields | Optional fields |
| --- | --- | --- |
| `username_password` | `identifier`, `secret` | None |
| `bearer_token` | `secret` | None |
| `static_token` | `secret` | None; describe header, cookie, or query placement in `description` |
| `signing` | `algorithm` and either `secret` for `hmac-*` or `key_pem` for other algorithms | None |
| `mtls` | `cert_pem`, `key_pem` | `ca_pem` |

Values are literal; Niro does not expand environment-variable references in
this file. Keep environment selection, login shape, effective permissions, and
credential usage in the description. Niro exposes the non-secret `identifier`
as `<CREDENTIAL_ID>_IDENTIFIER`, hides scalar authentication material behind
`<CREDENTIAL_ID>_SECRET`, and exposes private-key paths as
`<CREDENTIAL_ID>_KEY_PEM_FILE`. For mTLS, the certificate and optional CA paths
are `<CREDENTIAL_ID>_CERT_PEM_FILE` and `<CREDENTIAL_ID>_CA_PEM_FILE`.

Use the generated
[`credentials.yaml.example`](../examples/niro-config/credentials.yaml.example)
as the canonical format reference.

### `fixtures.yaml`

The top-level key is `fixtures`. Each entry requires a unique non-empty `name`,
a non-empty `description`, and a present `value`. The value can be any YAML
type, including `null` when intentionally unset. Keep secrets in
`credentials.yaml`, not fixtures. See the generated
[`fixtures.yaml.example`](../examples/niro-config/fixtures.yaml.example).

## Harness entry points

Use the script extension for the host running Niro: `.sh` on macOS/Linux or
`.ps1` on Windows.

| Operation | Existing runtime with `--url` | Niro-managed runtime without `--url` |
| --- | --- | --- |
| `start` | Not used | Build and start the current checkout, then verify health |
| `stop` | Not used | Stop the application and supporting services |
| `seed` | Create or reconcile dedicated test state and generate credentials and fixtures | Create deterministic baseline state and generate credentials and fixtures |
| `reset` | Optional clean-baseline operation | Restore the deterministic baseline |

The exact lifecycle contract is in the generated
[`harness/README.md`](../examples/niro-config/harness/README.md). Commit harness
scripts; do not commit their generated secrets or runtime state.
