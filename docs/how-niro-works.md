# How Niro Works

Niro is an autonomous penetration tester for your running application. Point it
at your app and it runs two roles — an **attacker agent** that finds and proves
real exploits, and a **developer agent** that patches them and records evidence
for each change. Model requests go directly to the provider configured for your
agent CLI; Niro does not proxy them through an APX Labs execution service.

## The two agents

- **The attacker agent** finds real, exploitable bugs in your running app,
  proves each one with a working exploit, and only reports what it can actually
  prove.
- **The developer agent** takes each proven finding, writes the patch and, when
  meaningful, a regression test that locks the fix in, then opens a review-ready
  pull request — one per root cause.

The developer agent only patches what the attacker agent proved. Each fix PR
records the test-level red-to-green evidence, full-suite result, and any
residual risk.

## Find and fix

Two commands put the attacker agent and developer agent to work:

- **`niro find`** runs the attacker agent alone: it pentests your app and writes a
  proven-findings report. Read-only — it never touches your code.
- **`niro fix`** runs the *same* pentest, then has the developer agent address
  every confirmed finding: one pull request per root cause, each carrying its
  patch and validation evidence.

`fix` is `find` plus the fixing. The attack is identical — `fix` simply acts on
what it proves. Run `find` when you want the proof; run `fix` when you want the
proof *and* the patches.

## Niro prepares the application

Both commands need your app running and reachable. Without `--url`, Niro
inspects the repository, starts the current checkout, and creates the users and
test data it needs. With `--url`, Niro uses that existing runtime and invokes
only the preparation operations committed for that environment.

See [Prepare your app](prepare-your-app.md) for both runtime paths.

## Sandboxed attack tools, reviewed fixes

The attacker agent invokes command-line and browser tools inside a container
whose network is fenced at the kernel layer to only the targets you authorize
in your scope. The developer agent runs on your host or CI runner and never
merges anything: it opens pull requests and stops. You review every diff and
decide what ships.
