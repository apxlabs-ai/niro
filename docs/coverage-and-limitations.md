# Coverage and limitations

Niro tests a running application for behavior an attacker can reproduce. Its
output is evidence about the application surfaces, identities, state, and time
covered by that run. It is not a certification that the application has no
other vulnerabilities.

## What determines coverage

Every run is bounded by four inputs:

| Input | What it controls |
| --- | --- |
| Run scope | The whole application, a plain-English goal, a commit range, or a pull-request or merge-request diff |
| Application runtime | The exact deployed application selected by `--url`, or the current checkout started by Niro |
| Test state | The users, roles, tenants, resources, feature flags, and integrations the preparation mechanism makes available |
| Network authorization | The hosts, CIDRs, and ports allowed by the selected `scope.yaml` |

Niro combines source and change context, when available, with observations from
the running application. It explores reachable workflows, creates additional
permitted test state when possible, and tests security invariants against the
live behavior.

Typical coverage includes authentication and session behavior, authorization
and tenant boundaries, server-side input handling, application workflows, and
exposed integrations. This list is illustrative. The exact test cases depend on
the application and run inputs rather than a fixed vulnerability checklist.

## What a finding means

Niro reports a finding only after reproducing the insecure behavior against the
running application. A proof should include both:

- an attack case that demonstrates the consequence; and
- a legitimate control case showing that the result is specific to the tested
  security boundary rather than a broken environment.

Potential issues that cannot be reproduced are not promoted to proven
findings. Review the proof bundle before relying on a finding or merging a fix.
See [Review the results](review-results.md).

## What a clean run means

A run with no findings means Niro did not prove an exploitable bug within the
surface, state, authorization, and limits of that run. It does not mean:

- every route, role, tenant, feature, or integration was exercised;
- unreachable or unconfigured behavior is secure;
- a focused goal or diff run covered the whole application;
- the deployed environment matches another environment; or
- future runs will produce the same result after the application changes.

Read the summary together with its coverage gaps and stop conditions. Do not
use the finding count alone as the security result.

## Common coverage boundaries

| Boundary | Effect on the result | Customer action |
| --- | --- | --- |
| Missing identities or roles | Cross-user, cross-tenant, or privilege-boundary tests may be impossible | Provide at least two distinct users for each role and tenant boundary that matters |
| Missing fixtures | Workflows with empty accounts or absent resources may not be reachable | Seed representative resources and record their non-secret identifiers in `fixtures.yaml` |
| Disabled features or integrations | Niro cannot test behavior that the selected environment does not expose | Enable a safe test path, provide a substitute, or record a reviewed coverage gap |
| Network scope | The sandbox cannot reach destinations absent from `scope.yaml` | Authorize only customer-owned hosts and required ports; never widen scope merely to clear an error |
| Run goal or diff | Focused runs prioritize behavior relevant to that input | Use a whole-application run when broader coverage is required |
| Time, budget, or concurrency limits | A run can stop with untested or blocked test cases | Focus the goal first; raise limits only when the additional coverage is intentional |
| Model or provider failure | Rate limits, authentication, or model capability can stop exploration | Correct provider access or reduce concurrency, then rerun the same scope |
| Environment mismatch | A staging result may not represent production configuration or data paths | Test the environment whose behavior matters, using a separately authorized profile |

## Pull-request and commit-range coverage

A pull-request, merge-request, or commit-range run is change-focused. Niro uses
the diff to select relevant runtime behavior; it is not a whole-application
assessment.

When `--url` is used with a change-focused run, the target must serve the
selected head revision. If Niro cannot establish that relationship, it should
not attribute runtime behavior to the change. Let Niro start the current
checkout when deployment provenance cannot be verified.

Use `niro find --pr-number` to review an open change without modifying its
branch. Use a commit range with `niro fix` when you want separate remediation
pull requests for findings related to an existing change.

## What Niro does not replace

Niro is an application penetration-testing and remediation workflow. It does
not replace controls whose primary evidence is outside the running application,
including:

- dependency inventory and software-composition analysis;
- secret scanning and repository policy enforcement;
- malware detection;
- cloud, host, identity-provider, or Kubernetes posture review;
- source-code proof or formal verification;
- load, capacity, resilience, or denial-of-service testing; or
- a compliance certification or independent human assessment.

Those controls can reveal risks that a runtime exploit cannot, and Niro can
find application behavior those controls cannot. Use them together where the
risk requires it.

## Remediation boundaries

`niro fix` attempts to remediate proven findings that can be addressed safely
in the checked-out repository. It may produce no fix when the required change
belongs to infrastructure, a third-party service, product policy, or an
environment Niro cannot modify safely.

A fix pull request normally contains red-to-green regression evidence and the
project's broader test result. When a meaningful automated regression test is
not practical, the pull request must identify the alternative evidence and
remaining uncertainty. Niro does not merge generated changes and does not
automatically run a new live pentest against every fix pull request.

Rerun Niro after deployment when you need confirmation against the updated
runtime.

## Human-owned decisions

Niro can propose entries for two reviewed registers:

- `accepted-behaviors.yaml` records specific behavior the team has decided is
  intentional; and
- `accepted-coverage-gaps.yaml` records a specific surface that is structurally
  unavailable in the selected environment.

Presence in either file changes future run behavior. Review and commit these
files as security decisions. Do not use a broad entry to silence a fixable setup
problem, and delete an entry when the underlying decision changes.

## Improve a run before increasing limits

Use this order:

1. Select the correct environment profile and runtime.
2. Authorize the exact target hosts and ports.
3. Seed distinct users, roles, tenants, and owned resources.
4. Give the run a focused goal when one workflow matters most.
5. Resolve every reported coverage gap or explicitly accept it.
6. Increase duration, budget, or concurrency only when the run still needs more
   room.

For setup details, see [Prepare your app](prepare-your-app.md). For exact flags
and limits, see [CLI and configuration reference](cli-and-config-reference.md).
