<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/niro-logo-dark.png">
    <img src="assets/niro-logo-light.png" alt="Niro" width="280">
  </picture>
</p>

# Niro Community Edition

> Finds the security bug. Ships the fix.

Niro works like an autonomous, two-person team living in your repo — two roles
with one goal: real security bugs, found and closed with proof.

Niro sets the stage first — it stands up your app (or points at a target you
provide), seeds test state, and creates the users and data an attacker needs, so
you skip most of the environment setup. Then the two-person team goes to work:

- **The attacker** hits your running app like a real adversary — finds
  exploitable bugs, proves each with a working exploit, re-tests after a fix.
  Never changes your code.
- **The developer** patches the bugs it can safely fix and adds a regression
  test for each fix — so every PR arrives with evidence it works, not just a
  claim. Never merges — you do.

Most security tools hand you a backlog of maybes and walk away. Niro doesn't stop
at proven findings — in fix mode it turns each into a focused **pull request**.
You review the diffs and decide what ships.

## From a three-team relay to one run

Fixing a security bug is a **relay across three teams** — today's tools each
cover one slice, so people stitch the rest together:

1. **Set up** the test environment — *engineering.*
2. **Attack** the app to find and exploit the bugs — *security.*
3. **Triage and fix** every finding — *developers.*

A **program manager** chases the handoffs, and it's never one clean pass. The
pentester needs another test tenant, back to eng. A finding won't reproduce, it
ping-pongs between security and dev. A fix ships, security has to re-test. Weeks
pass, a dozen people touch it, and the code has already moved on.

**Niro collapses that relay into one autonomous run.** Its **attacker** does the
security team's job, its **developer** does the dev team's — and it *automates
the setup* engineering used to own. You still set the scope, review the diffs,
and decide what merges; Niro handles the back-and-forth in between — so three
teams' effort lands in a few hours as review-ready pull requests, grouped by root
cause so each is small enough to actually review.

## Quickstart

From your project root, [check the prerequisites](docs/prerequisites.md), then
install Niro and start a fix run:

```bash
curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh | sh
niro fix
```

That's it. `niro fix` runs the end-to-end workflow and opens review-ready fix
PRs. You decide what to merge.

See [Run Niro](docs/run-niro.md) for report-only and scoped runs, supported
coding agents, CI, and agent-native workflows.

## What a run actually does

Setup done, Niro works your running app the way a real attacker would — and
doesn't stop until each bug is proven:

1. **Attack** — probes your HTTP surfaces (web apps, APIs, MCP servers) for real,
   exploitable bugs.
2. **Unblock** — when a login, empty database, disabled feature, or missing tenant
   blocks testing, Niro creates what it needs to keep going instead of silently
   skipping that part of the app.
3. **Prove** — every finding is a false alarm until Niro reproduces it and writes
   a test that fails on the bug. Doubt is demoted, never inflated.

Proven bugs are grouped by root cause into focused, review-ready PRs — one per
cause, each with its own regression test.

## Built for trust

AI makes code faster to ship and harder to trust. Niro is built to earn that
trust back:

- **Your environment, your provider.** Niro does not proxy model requests or
  require uploading your repository, credentials, findings, or logs to a Niro
  backend. See [Security and data](docs/security-and-data.md) for AI-provider
  boundaries, telemetry, and opt-out controls.
- **You set the blast radius.** The engine runs in a sandbox with kernel-level
  egress control — it can reach *only* the targets you authorize in `scope.yaml`,
  enforced at the network layer.
- **Transparent coverage.** Niro reports what it *couldn't* reach on every run, so
  coverage is never a black box — and it remembers intended behavior so it won't
  keep flagging it. Strongest on the everyday exploitable class; novel,
  multi-step business logic stays yours.

Need governance, audit, compliance, or enterprise deployment support? Talk to APX
Labs about Niro Enterprise.

## Docs

- **[Get started](docs/getting-started.md)** — prerequisites, installation, and
  your first run.
- **[Prepare your app](docs/prepare-your-app.md)** — targets, scope, credentials,
  fixtures, and test state.
- **[Run Niro](docs/run-niro.md)** — find or fix, local or CI, whole-app or
  focused.
- **[Review the results](docs/review-results.md)** — findings, exploits,
  regression tests, and fix PRs.
- **[Security and data](docs/security-and-data.md)** — data flow, AI providers,
  sandboxing, egress, and telemetry.
- **[Coverage and limitations](docs/coverage-and-limitations.md)** — what Niro
  tests, what it reports, and where humans remain responsible.
- **[Reference](docs/cli-and-config-reference.md)** — commands, flags, and
  configuration.
- **[Troubleshooting](docs/troubleshooting.md)** — common failures, diagnostics,
  and support artifacts.

## License

Apache License 2.0 ([LICENSE](LICENSE), [NOTICE](NOTICE)).

## Issues

<https://github.com/apxlabs-ai/niro/issues>
