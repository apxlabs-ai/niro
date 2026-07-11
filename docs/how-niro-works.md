# How Niro Works

Niro is an autonomous penetration tester for your running application. Point it
at your app and it plays two personas — an **attacker** that finds and proves
real exploits, and a **developer** that patches them and proves the fix. It runs
on your own model provider, so your code and prompts stay with you.

## The two personas

- **The attacker** finds real, exploitable bugs in your running app, proves each
  one with a working exploit, and — once a fix exists — re-tests to confirm the
  hole is closed. It only reports what it can actually prove.
- **The developer** takes each proven finding, writes the patch and a regression
  test that locks the fix in, and opens a review-ready pull request — one per
  root cause.

Neither invents work for the other: the developer only patches what the attacker
proved, and the attacker re-tests what the developer patched.

## Find and fix

Two commands put those personas to work:

- **`niro find`** runs the attacker alone: it pentests your app and writes a
  proven-findings report. Read-only — it never touches your code.
- **`niro fix`** runs the *same* pentest, then turns the developer loose on every
  confirmed finding: one pull request per root cause, each carrying its patch and
  regression test.

`fix` is `find` plus the fixing. The attack is identical — `fix` simply acts on
what it proves. Run `find` when you want the proof; run `fix` when you want the
proof *and* the patches.

## Niro builds the harness

Both commands need your app running and reachable, and Niro stands that up for
you rather than making you prepare an environment by hand. It inspects the repo,
boots the app from your working tree, seeds test state, and creates the users and
resources an exploit needs — then records those reference points so later runs
start faster.

## Caged attacker, reviewed developer

Niro fires real exploits, so the attacker runs **caged**: inside a container
whose network is fenced at the kernel layer to only the targets you authorize in
your scope. And the developer never merges anything — it opens pull requests and
stops. You review every diff and decide what ships.
