# Security policy

Niro is a security testing product that runs privileged automation against
systems you authorize. Report a suspected vulnerability in Niro privately so
APX Labs can investigate it before details or working exploits are made public.

## Supported versions

Niro Community Edition follows a rolling pre-1.0 release policy. Security
support applies to the latest patch release of the current minor line.

| Version | Security support |
| --- | --- |
| Latest patch release of the current minor line | Supported |
| Final patch release of the previous minor line | Supported for 30 calendar days after the next minor line is released |
| All other releases | Unsupported |

For example, while `0.1.x` is current, its latest patch is supported. After
`0.2.0` is released, the final `0.1.x` patch remains supported for a 30-day
migration window. Fixes normally ship in a new patch release; APX Labs does not
backport fixes to every earlier patch. A supported resolution may require an
upgrade.

Starting with `v0.1.53`, patch releases preserve the documented CLI,
configuration, and MCP contracts. A planned incompatible change belongs in a
new minor line and must include migration guidance in its release notes.

This Community Edition policy covers eligibility for security fixes and public
compatibility guidance. It does not include an individual response-time or
remediation SLA. Niro Enterprise support terms will be defined separately.

## Report a vulnerability

Email [security@apxlabs.ai](mailto:security@apxlabs.ai). Do not open a public
issue for an unpatched vulnerability.

Include what you can safely provide:

- the Niro version and operating system;
- whether the issue affects the CLI, installer, attack-tool sandbox image,
  release process, or documentation;
- reproduction steps or a minimal proof of concept;
- the security impact and required preconditions; and
- any temporary mitigation you found.

Do not send customer credentials, proprietary source code, production data, or
an exploit against a system you are not authorized to test. APX Labs may ask
for additional evidence through a safer channel.

## Scope

This policy covers vulnerabilities in Niro Community Edition, its installers,
the published attack-tool sandbox image, and the APX Labs release artifacts.
Vulnerabilities that Niro discovers in a customer's application belong to that
customer's disclosure process, not this one. Vulnerabilities in an agent CLI,
container runtime, Git provider, or other third-party component should also be
reported to that component's maintainer.

## Coordinated disclosure

Please allow APX Labs a reasonable opportunity to investigate, prepare a fix or
mitigation, and notify affected users before public disclosure. APX Labs will
coordinate disclosure timing and credit with the reporter when practical.
