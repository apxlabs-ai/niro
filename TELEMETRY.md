# Telemetry

Your source code, your credentials, your live traffic, and your security
findings never leave your machine. What Niro collects is limited to the
usage data below — counts, timings, and cost — so we can see what's working and
make the product better.

Telemetry is **enabled by default** and can be turned off at any time (see [Opt
out](#opt-out)).

## What's collected

Every pentest that reaches a terminal state (completed or failed) emits exactly
one event. Nothing else is sent during a run. The event contains:

| Field | What it is |
|-------|------------|
| Schema version | Event format version, e.g. `1` |
| Installation ID | A random ID for your install |
| Pentest ID | An ID for the pentest, e.g. `niro_pt_a1b2c3d4` |
| Outcome | `completed` or `failed` |
| Timestamps | When the pentest started and completed |
| Niro version | CLI version, e.g. `0.2.0` |
| OS / architecture | Platform, e.g. `darwin` / `arm64` |
| Container runtime | `docker` or `podman` |
| Coding agent | Which agent drove the run — `claude`, `copilot`, or `codex` |
| Mode | PR-triggered or developer-directed |
| Duration | Run time in seconds |
| Model cost | Total LLM cost for the run, in USD |
| Severity floor | Configured minimum severity, e.g. `MEDIUM` |
| Coverage gaps | Number of surfaces Niro couldn't test |
| Per-severity counts | For each severity (critical/high/medium/low): open (unresolved), fixed (resolved this run), and blocked (couldn't run) |
| Repo hash | A hash of your repo's remote URL |
| PR hash | A hash of repo hash + PR number, PR mode only |

## Where it goes

The usage event is sent to [PostHog](https://posthog.com) (`us.i.posthog.com`).

## Opt out

Set `telemetry: false` in your project's `niro/niro.yaml`:

```yaml
telemetry: false
```

Commit it and the whole team inherits the opt-out.
