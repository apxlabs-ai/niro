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

Niro is source-available under the
[Functional Source License (FSL-1.1-Apache-2.0)](LICENSE.md): use, modify,
and run it freely for any purpose other than building a competing security
product. Each release converts to Apache 2.0 two years after publication.

*Source release is staged. This repository currently distributes binary
releases; the source will be published here under the same license.*
