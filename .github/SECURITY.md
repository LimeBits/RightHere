# Security Policy

## Supported Versions

Security fixes are currently provided for the latest release in the `0.4.x` series.

| Version | Supported |
| --- | --- |
| 0.4.x | Yes |
| < 0.4.0 | No |

## Reporting a Vulnerability

Please do not report security vulnerabilities in a public issue or discussion.

Use GitHub's private vulnerability reporting form:

<https://github.com/LimeBits/RightHere/security/advisories/new>

Please include:

- the affected RightHere version and macOS version;
- clear steps to reproduce the issue;
- the expected and actual behavior;
- any proof of concept, logs, or screenshots that help confirm the issue.

The maintainer will acknowledge a report as soon as practical, investigate its impact,
and coordinate a fix or mitigation before public disclosure where appropriate. Please
avoid including personal data or production secrets in a report.

## Release Verification

Official macOS releases are published through GitHub Releases. Release DMG files are
Developer ID signed and notarized by Apple. Each release includes a SHA-256 checksum.
RightHere's Sparkle update feed is signed and is served over HTTPS.

Before installing a release, verify that it was downloaded from the official repository:

<https://github.com/LimeBits/RightHere/releases>
