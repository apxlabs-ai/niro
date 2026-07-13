# Release notes

These files are the customer-facing contract for each Niro release. The release
workflow refuses to publish a tag unless its matching `vX.Y.Z.md` file exists,
matches the tag, and contains non-empty sections for:

- Summary
- Changes
- Security
- Compatibility and upgrade
- Known issues

Write for a customer deciding whether and how to upgrade. State "None" or "No
known issues" when that is the truthful result; do not omit a section. Internal
commit subjects can provide traceability but are not a substitute for behavior,
risk, and migration information.
