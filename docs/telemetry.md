# Telemetry

Niro emits product-usage and aggregate security-value telemetry for pentests. Telemetry does
not include source code, prompts, credentials, target URLs, raw HTTP traffic,
finding text, exploit payloads, or logs.

Telemetry is enabled by default and can be disabled per project. The setting is
read when a run starts, so the same committed policy applies to local and CI
runs.

## What is collected

### Accepted repository use

After a repository-backed `start_pentest` passes preflight and Niro persists
the running state, Niro resolves the provider's stable repository ID and emits
`repository_used`:

```json
{
  "installation_id": "550e8400-e29b-41d4-a716-446655440000",
  "repository_scope": "github.com",
  "repository_id": "1244024769",
  "repository_name": "apxlabs-ai/niro",
  "occurred_at": "2026-07-25T18:05:42Z"
}
```

| Field | Description |
| --- | --- |
| `installation_id` | Random identifier created for the local Niro installation. |
| `repository_scope` | Namespace in which the provider's repository ID is unique, such as `github.com`, a self-managed GitLab domain, `dev.azure.com/acme`, or `aws:111111111111:us-east-2`. |
| `repository_id` | Stable provider-native repository ID, stored as a string. |
| `repository_name` | Current readable repository name. This can identify a public or private repository and is not pseudonymous. |
| `occurred_at` | UTC time at which Niro accepted the run. |

The stable repository key is `(repository_scope, repository_id)`;
`repository_name` is display metadata and can change after a rename or
transfer.

Niro reads the origin remote and uses the authenticated provider CLI to resolve
the stable ID: `gh` for GitHub, `glab` for GitLab, `az` for Azure DevOps, and
`aws` for CodeCommit. The provider receives a repository metadata request. If
the run has no project root or Niro cannot resolve the identity, this event is
not sent.

### Terminal pentest

Every accepted pentest that reaches a terminal state emits `pentest_result`:

```json
{
  "installation_id": "550e8400-e29b-41d4-a716-446655440000",
  "repository_scope": "github.com",
  "repository_id": "1244024769",
  "run_id": "019c-c7f2-7df8-a427",
  "completed_at": "2026-07-25T19:05:42Z",
  "outcome": "completed",
  "critical": 1,
  "high": 2,
  "medium": 3,
  "low": 0,
  "source_available": true,
  "local_runtime": true
}
```

| Field | Description |
| --- | --- |
| `installation_id` | Random identifier created for the local Niro installation. |
| `repository_scope`, `repository_id` | Stable provider-native repository identity shared with `repository_used`. Omitted when the run had no repository. |
| `run_id` | Random identifier for this accepted run. |
| `completed_at` | UTC time at which the run reached terminal state. |
| `outcome` | `completed` or `failed`. |
| `critical`, `high`, `medium`, `low` | Unique, evidence-backed vulnerabilities delivered at each severity. |
| `source_available` | Whether source was under test. `false` for an external target with no source. |
| `local_runtime` | Whether the target was loopback-class (`localhost`, `127.0.0.1`, `::1`, `0.0.0.0`) — an application running on the same machine. A single true/false; the target URL itself is never sent. |

Severity counts include unique final `FAILED` test cases and findings that were
previously `FAILED` but retested as `PASSED` in this run. They exclude
`BLOCKED`, `DRAFT`, ordinary `PASSED`, below-threshold, and development-only
test cases. Failed runs have zero severity counts.

A retested `PASSED` finding says only that its exploit no longer reproduced in
the tested code. This telemetry does not show whether Niro created a fix or
pull request, whether a pull request was merged, or whether a change was
deployed.

The event has no free-text field for URLs, findings, prompts, commands, or
application data.

Repository identity is resolved once per accepted run and shared by both
events. It is not always available: a run against a target with no source — an
external URL — has no repository, and a lookup can fail on its own. In either
case `repository_used` is not sent and `pentest_result` omits
`repository_scope` and `repository_id`; the run is still reported, keyed on
the installation ID. `source_available` distinguishes the two situations.

### PostHog SDK metadata

Both events use the installation ID as PostHog's `distinct_id`. The PostHog Go
SDK also adds an event UUID, transport timestamp, SDK name and version,
`$os`, `$os_version` when available, `$os_distro` on Linux, `$go_version`,
`$geoip_disable: true`, and `$is_server: true`.

## Where it goes

Events are sent to Niro's PostHog project at `us.i.posthog.com`. Telemetry is
sent asynchronously, and a telemetry failure does not fail or delay the
pentest result.

The installation ID is stored locally in Niro's operating-system configuration
directory as `telemetry.json` so runs from the same installation can be
correlated. The file contains only `installation_id`.

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
