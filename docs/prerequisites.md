# Prerequisites

Niro orchestrates tools you already use. Run this to check your setup — if a
command fails, that's what you need to install:

```bash
docker --version || podman --version               # container runtime (the sandbox)
claude --version                                   # agent CLI (or: codex / copilot)
git --version                                      # version-control foundation
gh --version || az --version || glab --version     # your Git provider's CLI
```

## A container runtime

The attacker agent can fire real exploits, so its command-line and browser
tools run inside a container whose network is fenced at the kernel layer. Those
tools can reach only the targets in your `scope.yaml`. The attacker agent itself
runs on your workstation or CI runner and connects to your configured AI
provider there.

- **macOS / Windows:** [Docker Desktop](https://docs.docker.com/get-started/get-docker/)
- **Linux:** [Docker Engine](https://docs.docker.com/get-started/get-docker/) or [Podman](https://podman.io/docs/installation)

## An agent CLI

This is the agent CLI Niro drives to run both roles — the attacker agent that
exploits, and the developer agent that fixes. Install the one you use and sign
it in. Model requests go directly to the provider configured for that agent CLI;
Niro does not proxy them through an APX Labs execution service.

| Agent CLI | Install | Select it in Niro |
| --- | --- | --- |
| Claude Code | [install](https://code.claude.com/docs/en/overview) | default |
| OpenAI Codex | [install](https://developers.openai.com/codex/cli) | `--agent=codex` |
| GitHub Copilot CLI | [install](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli) | `--agent=copilot` |

## Git

Niro works natively in your repo and ships fixes as PR branches — git is the
foundation everything else sits on. You almost certainly have it already; if not:
[git-scm.com/downloads](https://git-scm.com/downloads) (`brew install git` on macOS).

## Sign in to your Git provider

Shipping proven fixes as PRs is the whole point — set up your provider's CLI once
and every run just works (`niro fix` opens the PRs, `niro find --pr-number` reads
them):

- **GitHub:** `gh auth login` ([GitHub CLI](https://cli.github.com/))
- **Azure DevOps:** `az login` ([Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli))
- **GitLab:** `glab auth login` ([GitLab CLI](https://gitlab.com/gitlab-org/cli))
