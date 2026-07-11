# Application preparation

This directory makes application state repeatable. The required operations
depend on where the application runs.

During `niro find` and `niro fix`, Niro invokes the applicable approved
operations before testing and whenever it needs a clean baseline. Review and
commit them so a local or CI run prepares the same state every time.

Use these conventional entry points on the platform that runs Niro:

| Operation | macOS/Linux | Windows |
| --- | --- | --- |
| `start` | `start.sh` | `start.ps1` |
| `stop` | `stop.sh` | `stop.ps1` |
| `seed` | `seed.sh` | `seed.ps1` |
| `reset` | `reset.sh` | `reset.ps1` |

You need only the scripts required by the selected runtime and platform. A thin
script may invoke an existing Make target, package script, API client, or staging
job rather than duplicate the application's setup logic.

## Existing application runtime

Supplying `--url` to `niro find` or `niro fix` selects this contract. Niro does
not start or stop the application at that URL. Provide only the preparation
operations the environment needs:

| Operation | Contract |
| --- | --- |
| `seed` | Create or reconcile dedicated test users, tenants, roles, and resources; generate `../credentials.yaml` and `../fixtures.yaml` |
| `reset` | Optional. Restore the dedicated test state to a clean baseline when a run can leave it changed |

Use an approved application API, staging job, or existing seed tool. Keep the
operation idempotent and scoped to dedicated test data. It must not provision a
different target, widen `../scope.yaml`, or mutate unrelated staging data.

The committed staging scripts are customer-approved operations. Niro may invoke
them, but it does not rewrite, extend, or replace them during an assessment. If
they cannot produce required state or access, Niro reports the blocker for a
person to resolve.

Retrieve secrets through the customer's existing secret-management path. Write
raw credentials only to `../credentials.yaml`; write non-secret identifiers and
references to `../fixtures.yaml`. Niro adds both generated files to `.gitignore`.

If signup and normal application flows can create all required state, the seed
operation may drive those flows rather than use database or infrastructure
access. Niro does not assume permission to administer the staging environment.

## Niro-managed application runtime

Omitting `--url` selects this contract. Niro starts the application from the
current checkout and provides the full lifecycle:

| Operation | Contract |
| --- | --- |
| `start` | Build the current checkout, start the full service graph, and verify every tested surface is healthy |
| `stop` | Shut down the application and supporting services cleanly |
| `seed` | Create a deterministic baseline and generate `../credentials.yaml` and `../fixtures.yaml` |
| `reset` | Restore that clean baseline between runs |

Use the application's own development path. Prefer its existing Dockerfile or
Compose file, language, factories, migrations, and seed helpers. Keep lifecycle
commands as thin orchestration around those tools and verify them on the
operating system they support.

## State and source

Commit preparation scripts and configuration under `niro/harness/`.
Keep mutable databases, logs, snapshots, and build output owned by the harness
under `niro/harness/run/`; Niro adds that directory to `.gitignore`.

Treat application source outside `niro/` as read-only for harness
state. The harness may build the project normally, but it should not scatter its
own databases, logs, or generated runtime files throughout the source tree.

For a Niro-started application, build from the current checkout rather than a
published image. This ensures the target contains the code Niro is reviewing.
