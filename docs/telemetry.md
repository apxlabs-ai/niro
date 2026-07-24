# Telemetry

Niro emits pseudonymous operational telemetry when a pentest completes or
fails. Telemetry does not include source code, prompts, credentials, target
URLs, raw HTTP traffic, finding text, exploit payloads, or logs.

Telemetry is enabled by default and can be disabled per project. The setting is
read when a run starts, so the same committed policy applies to local and CI
runs.

## What is collected

Every pentest that reaches a terminal state emits one event with these fields:

| Field | Description |
| --- | --- |
| Schema version | Version of the telemetry event format. |
| Installation ID | Random identifier created for the local Niro installation. |
| Attack-tool sandbox correlation | Pseudonymous value derived from the Niro config directory for internal lifecycle correlation. |
| Outcome | `completed` or `failed`. |
| Timestamps | UTC start and completion times. |
| Niro version | Version of the Niro CLI. |
| OS and architecture | Host platform, such as `darwin` and `arm64`. |
| Container runtime | `docker` or `podman`. |
| Agent | `claude`, `codex`, or `copilot`. |
| Mode | `pr`, `range`, or `directed`. |
| Duration | Run time in seconds. |
| Severity floor | Configured minimum finding severity. |
| Coverage-gap count | Number of known surfaces Niro could not test. |
| Finding counts | Open, fixed, and blocked counts for each severity. |
| Repository hash | SHA-256 hash of the repository's remote URL when repository hashing is enabled. |
| PR hash | SHA-256 hash derived from the repository hash and PR number. Present only for PR runs when the repository hash is available. |

The event schema contains no free-text field for URLs, findings, prompts,
commands, or application data. Repository and PR hashes are stable,
pseudonymous identifiers; they are not anonymous data.

## Where it goes

The event is sent to Niro's PostHog project at `us.i.posthog.com`. Telemetry is
sent asynchronously, and a telemetry failure does not fail or delay the
pentest result.

The installation ID is stored locally in Niro's operating-system configuration
directory as `telemetry.json` so runs from the same installation can be
correlated.

## Disable telemetry

Set `telemetry: false` in the project's `niro/niro.yaml`:

```yaml
telemetry: false
```

Commit the setting so every developer and CI run inherits the opt-out.

When Niro reads that configuration for `start_pentest`, it writes a
`telemetry_disabled` record with the selected `niro.yaml` path to
`niro-activity.host.jsonl`. Niro does not report telemetry as enabled during
`niro serve` startup because no project configuration has been selected yet.

Telemetry is controlled per Niro configuration. If a repository uses separate
configuration directories for multiple environments, set the policy in each
directory's `niro.yaml`.

## Related security boundaries

Telemetry is only one of Niro's external data paths. The selected AI provider,
Git provider, CI system, and target application have separate data flows and
retention policies. See [Security and data](security-and-data.md) for the
complete boundary model.
