# Releases, support, and verification

Niro Community Edition is proprietary software distributed as prebuilt release
artifacts. The public repository contains documentation, installers, examples,
and releases; it does not contain the Niro product source or build system.

## Release artifacts

Each GitHub release can contain:

| Artifact | Purpose |
| --- | --- |
| `niro_<os>_<arch>.tar.gz` or `.zip` | Platform-specific CLI archive |
| `niro.mcpb` | Multi-platform MCP Bundle |
| `checksums.txt` | SHA-256 digests generated with the release |
| `ghcr.io/apxlabs-ai/niro-agent:<version>` | Multi-architecture attack-tool sandbox image |

Use the [GitHub Releases](https://github.com/apxlabs-ai/niro/releases) page as
the canonical download index. A release note describes customer-visible
changes, security impact, compatibility, upgrade actions, and known issues.

## Supported versions

The latest patch release of the current minor line is supported. When a new
minor line is published, the final patch of the previous minor line has a
30-day migration window. See the [security policy](../SECURITY.md) for the
complete support and reporting contract.

Old artifacts remain downloadable so builds can stay pinned and historical
runs can be investigated. Availability does not mean that an old release is
still supported.

## Install, select a channel, or pin a version

The same installer URL supports stable, dev, and release-candidate builds:

| Selection | Installed release |
| --- | --- |
| No selector | Latest published stable release |
| `NIRO_CHANNEL=stable` | Latest published stable release |
| `NIRO_CHANNEL=dev` | Latest published `vX.Y.Z-dev.N` prerelease |
| `NIRO_CHANNEL=rc` | Latest published `vX.Y.Z-rc.N` prerelease |
| `NIRO_VERSION=<tag>` | That exact stable, dev, or RC release |

For example, install the current dev channel on macOS or Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh \
  | NIRO_CHANNEL=dev sh
```

On Windows PowerShell:

```powershell
$env:NIRO_CHANNEL = "dev"
irm https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.ps1 | iex
```

The installers resolve a moving channel to an exact published tag and print it
before downloading. They reject unknown channels and reject invocations that
set both `NIRO_CHANNEL` and `NIRO_VERSION`. Dev and RC builds are public early-
access artifacts for testing; the supported-version policy applies to stable
releases.

To pin a macOS or Linux installation, pass `NIRO_VERSION` to the shell that
runs the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh \
  | NIRO_VERSION=v0.1.53 sh
```

On Windows PowerShell:

```powershell
$env:NIRO_VERSION = "v0.1.53"
irm https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.ps1 | iex
```

Run `niro version` after installation. Run `niro upgrade` to replace an
existing macOS or Linux CLI with the latest supported stable release. The
standalone upgrader does not follow a dev or RC channel, so prerelease test
instructions should retain the resolved exact tag.

Windows users must rerun the installer to upgrade. The standalone upgrader
currently expects a tar archive while Windows releases use ZIP.

Pinning provides repeatability, not extended support. Review newer release
notes regularly and move to a supported patch before requesting assistance.

## Verify a CLI archive

The installers automatically download `checksums.txt` and verify the selected
archive before replacing the CLI. For a manual verification, download the
archive and `checksums.txt` from the same versioned release, then run the
platform's SHA-256 tool. For example:

```bash
grep ' niro_linux_amd64.tar.gz$' checksums.txt | shasum -a 256 -c -
```

An `OK` result shows that the archive matches the digest APX Labs published for
that release. Checksums detect corruption and mismatched files. However,
checksums do not prove who published the binary when the file and digest come
from the same release channel.

Niro does not yet publish a detached signature, public binary provenance
attestation, or release SBOM. Those are current supply-chain limitations, not
properties implied by checksum verification.

## Verify and record the sandbox image

Released CLIs pull the version-matched image tag, for example:

```text
ghcr.io/apxlabs-ai/niro-agent:0.1.53
```

Both `v0.1.53` and `0.1.53` tag forms identify the same multi-architecture
image at release time. A tag can be republished, while an image digest is
content-addressed. Record the image digest when an audit needs an immutable
identity:

```bash
docker buildx imagetools inspect ghcr.io/apxlabs-ai/niro-agent:0.1.53
```

Look for the top-level `Digest` or `digest` value and retain it with the run's
Niro version and results.

## Release-note contract

Every new tag must have a reviewed file under `releases/` before the release
workflow publishes artifacts. Each note includes:

- a plain-language summary;
- customer-visible changes;
- security fixes or an explicit statement that there were none;
- compatibility and required upgrade actions; and
- known issues or an explicit statement that none are known.

Raw commit subjects may supplement this information, but they are not the
customer release contract.
