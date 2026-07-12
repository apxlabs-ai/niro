# Review the results

Start with the run summary. Open proof bundles and fix pull requests only when
you need the evidence behind a finding or are deciding whether to merge a fix.

## Find the summary

| Where Niro ran | Where to look |
| --- | --- |
| Local terminal | `niro-summary.md` in the repository root |
| GitHub Actions | The workflow run's job summary |
| GitLab CI/CD | The `niro-summary.md` job artifact |
| Pull-request or merge-request review | The change-request comment and status, plus the CI summary or artifact |

The final terminal message also names the result locations produced by that
run. A run that ended before the handoff may have no findings summary.

The summary is deliberately short. It tells you:

- what an attacker can do for each proven finding;
- which pull request or patch addresses it in a `fix` run;
- any behavior Niro proposes treating as intentional;
- which application surfaces remain untested; and
- any material risk left by a proposed fix.

Use the consequence, not the number of rows, as the primary signal. The decision
is whether the described attacker capability matters in your deployment.

## Inspect a proven finding

Local runs write `niro-knowledge.tar` when there is reusable configuration or
finding evidence to preserve. The GitHub and GitLab examples publish the same
file as a CI artifact. List its contents before extracting it:

```bash
tar -tf niro-knowledge.tar
```

The archive can also contain committable Niro configuration changes, including
updates to accepted-behavior and coverage-gap registers. It excludes raw
credentials, fixtures, and harness runtime state. Setting
`--include-findings=false` also excludes finding proof bundles.

Each proven finding is stored under:

```text
<config-dir>/findings/<finding-id>/
  finding.json
  poc.<ext>
  run.sh | run.ps1
```

Review these files together:

| File | What it establishes |
| --- | --- |
| `finding.json` | The affected behavior, consequence, attack steps, and Niro's recorded finding |
| `poc.<ext>` | A runnable proof against the application using the project's language |
| `run.sh` or `run.ps1` | The command and environment needed to execute the proof |

A proof should reproduce the insecure behavior against a healthy target and
include a legitimate control showing the failure is specific, not a broken
environment. Use dedicated test data when replaying it. Do not run a proof
against a shared or production environment unless that exact activity is
authorized.

Finding bundles can contain sensitive vulnerability details and application
responses. Keep them in access-controlled storage and apply an appropriate
retention policy. They are included for review, not for commit.

`niro-debug-logs.tar`, when explicitly enabled, is a separate support artifact
that can contain sensitive raw logs. Upload or share it only intentionally.

## Review a fix pull request

Niro groups findings that share one root cause into one focused pull request or
merge request. Read the PR body before the diff; it is structured to answer the
review questions in order:

| Section | What to verify |
| --- | --- |
| Summary | The issue and proposed fix are understandable in product and code terms |
| Consequence | The attacker capability matches the finding you intend to fix |
| Reproduction | The recorded requests and responses prove the vulnerable behavior without exposing secrets |
| What changed | The patch addresses the root cause rather than one symptom |
| Regression test | The test asserts the security invariant in the project's normal test suite |
| Validation | The test failed on the vulnerable code and passed after the fix |
| Full suite | Existing tests passed, or any incomplete or failing validation is stated plainly |
| Residual risk | Anything the patch does not prove or intentionally leaves open |

When a meaningful automated regression test is not possible, the PR should say
why and include the strongest integration or manual proof available. A missing
test without that explanation is a review blocker.

Then inspect the code and test as you would any security-sensitive change. Pay
particular attention to authorization boundaries, compatibility, error paths,
and whether the regression test includes a valid allowed case alongside the
blocked attack.

A draft PR means the correct behavior requires a product, policy, or deployment
decision. Niro recommends a direction but does not make that tradeoff for you.

## Understand what was verified

Before remediation, Niro reproduces each reported vulnerability against the
running application. During remediation, Niro normally verifies the proposed
fix with a regression test that goes red on the vulnerable code and green after
the patch, then runs the project's test suite. When that test is not meaningful
or practical, the PR must identify the alternative evidence and the remaining
uncertainty.

Niro does not automatically run a new live pentest against each fix PR. The PR
must say when a regression test or full-suite run was incomplete. After merging,
run Niro again when you need deployment-level confirmation against the updated
application.

## Review proposed accepted behavior

Niro may add an entry to `accepted-behaviors.yaml` when evidence suggests a
finding is intentional. This is a proposal, not an automatic risk acceptance.

Review the consequence and cited evidence. Keep the entry only when the behavior
is genuinely intended and acceptable for the deployed environment. Delete it
when the behavior should remain a bug; future runs can then report it again.

## Review coverage gaps

`accepted-coverage-gaps.yaml` records application surfaces Niro could not test,
such as an unavailable identity provider or licensed integration. A coverage gap
is unknown risk, not a clean result.

Decide whether to provide the missing state or dependency and rerun, test the
surface separately, or explicitly carry the limitation. Do not compare finding
counts across runs without also comparing their coverage gaps.

## When there is no fix PR

A completed run can legitimately produce no fix pull request:

- no exploitable finding was proven;
- you ran `niro find`, which never creates fix branches or PRs;
- the run stopped before remediation and the summary names the blocker; or
- Git-provider authentication was unavailable and Niro produced a patch fallback.

Use the summary, finding proof, and residual-risk notes to distinguish these
outcomes. Do not interpret "no PR" by itself as "no vulnerability."

## Decide what to merge

Merge only when you agree with the security behavior, the validation evidence
establishes the intended boundary, the evidence is complete enough for the risk,
and any residual risk is acceptable. Niro never merges generated changes.

For storage, deletion, AI-provider, and telemetry boundaries, see
[Security and data](security-and-data.md).
