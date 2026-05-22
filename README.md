# Niro

> Push a PR. Niro hacks it. Your agent patches it.

Niro is a security agent that runs from your coding agent. When you push a
PR, your agent calls Niro over MCP; Niro probes the changed code as an
attacker would and returns reproducible exploits. Your agent writes a
regression test for each finding, fixes the code, and re-runs Niro to
confirm closure — before CI finishes, without a human in the triage loop.

## Install

**macOS, Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.ps1 | iex
```

## License

Niro binary releases are distributed under the
[Apache License 2.0](LICENSE). Install, run, redistribute, and
build on niro freely. See [NOTICE](NOTICE) for attribution.

*This repository currently distributes binary releases only.
Source remains private at this stage.*
