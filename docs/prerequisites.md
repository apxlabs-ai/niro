# Prerequisites

Niro orchestrates tools you already use. Run this to check your setup — if a
command fails, that's what you need to install:

```bash
docker --version || podman --version               # container runtime (the sandbox)
claude --version                                   # agent (or: codex / copilot)
git --version                                      # version-control foundation
gh --version || az --version || glab --version     # your Git provider's CLI
```

## A container runtime

Niro runs an autonomous attacker that fires real exploits. To keep your machine
safe, it runs *caged*: inside a container whose network is fenced at the kernel
layer, restricted to only the targets in your `scope.yaml`. Docker or Podman is
the cage.

- **macOS / Windows:** [Docker Desktop](https://docs.docker.com/get-started/get-docker/)
- **Linux:** [Docker Engine](https://docs.docker.com/get-started/get-docker/) or [Podman](https://podman.io/docs/installation)

## An agent

This is the reasoning engine Niro drives to play both roles — the attacker that
exploits, and the developer that fixes. Install the one you use and sign it in;
it runs on your own model provider (your API key or subscription — none of your
code or prompts route through Niro).

| Agent | Install | Select it in Niro |
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
