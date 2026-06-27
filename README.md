<p align="center">
  <img src="assets/niro-logo.png" alt="Niro" width="280">
</p>

# Niro

> Security that keeps up with your developers.

Niro pentests your running application and opens review-ready fix PRs with
security regression tests, so security fixes land as normal pull requests.

Today, a pentest starts with a handoff: prepare a runtime, define scope, gather
credentials and fixtures, wait for findings, triage them, reproduce them, write
tests, and make the fix. By the time it becomes merged code, weeks or months
can pass and several people have touched the work.

Meanwhile, the codebase has already moved on. AI coding tools make that gap
wider: teams are shipping more code than security can review.

## Why Now

AI has made code faster to ship and harder to trust.

| Signal | What it means |
| --- | --- |
| 85% say AI has shifted the bottleneck from writing code to reviewing and validating it [[1]](#references) | Speed is no longer the hard part. Trust is. |
| 90% of security leaders report concern about AI-generated software risk [[2]](#references) | AI-written code is now a security governance problem, not just a developer productivity story. |

## Why Niro

Niro collapses app setup, pentesting, and fixing into one repo-native loop.
Instead of handoffs across several people, Niro brings up the app, tests it,
and opens PRs that fix security issues with security regression tests. Work
that can take weeks or months and touch several people can start landing in
hours.

## What Niro Does

- **Builds the harness:** creates the scripts and config needed to start the
  app, seed credentials and data fixtures, and make the target testable across
  languages, frameworks, and databases.
- **Probes HTTP attack surfaces:** exercises APIs, web flows, MCP servers, and
  other HTTP endpoints against OWASP Top 10-style risks inside your scope.
- **Adapts when others stop:** when testing hits missing users, tenants, data,
  credentials, routes, or feature state, Niro updates the harness, builds the
  state it needs, and avoids silent coverage gaps.
- **Turns confirmed issues into focused PRs:** groups related issues by root
  cause, adds security regression tests, patches code, and opens review-ready
  PRs.
- **Runs where your code runs:** locally or in CI, using your environment and
  your credentials.

## Trust And Control

- **Data privacy:** app traffic, credentials, and test state stay in your
  environment; AI reasoning uses the provider account you configure.
- **Agent containment:** Niro applies kernel-level egress controls from
  `scope.yaml`, so the pentest engine can only reach approved targets.
- **Alert fatigue:** Niro checks code, tests, config, prior accepted behavior,
  and existing PRs before opening a PR. Clear bugs become fix PRs;
  intentional or ambiguous behavior is recorded for your review.
- **Runaway cost:** customize `niro.yaml` to control time, cost, and
  concurrency.
- **Telemetry control:** usage telemetry is documented in
  [TELEMETRY.md](TELEMETRY.md) and can be disabled in `niro.yaml`.

## Quickstart

Pentest an application from your machine:

```bash
git clone https://github.com/<your-org>/<your-repo>.git
cd <your-repo>
curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh | sh
niro init
claude "Pentest this application and create PRs."
```

See [Run Niro](docs/run-niro.md) for Windows installation, prerequisites, CI,
and other coding-agent examples.

## Ways To Run Niro

Niro runs locally or in CI, and can target a whole app, a focused scope, or a
pull request.

- **Local:** run from a developer machine when you want interactive control.
- **CI:** run from a workflow when you want repeatable pentest-to-PR automation.
- **Whole app or focused scope:** test the application area you choose.
- **Pull request:** test changes before they merge.

See [Pentesting Without The Setup Tax](docs/pentesting-without-the-setup-tax.md)
for harness, fixtures, and setup-gap handling.

## References

1. [ITPro on GitLab's AI code governance report](https://www.itpro.com/software/development/enterprises-are-shipping-so-much-ai-generated-code-they-cant-control-or-secure-it)
2. [TechRadar on Salt Security's AI code risk research](https://www.techradar.com/pro/security/nearly-all-security-bosses-are-worried-about-ai-safety-with-a-third-saying-they-still-rely-on-manually-reviewing-code-before-launch)

## License

Apache License 2.0 ([LICENSE](LICENSE), [NOTICE](NOTICE)).

## Issues

<https://github.com/apxlabs-ai/niro/issues>
