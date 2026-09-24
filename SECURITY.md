# Security Policy

`cashfree_pg` is used in payment flows, so security reports are handled with priority.

## Supported versions

Until v1.0.0, only the latest released minor version receives security fixes.

## Reporting a vulnerability

**Do not open a public issue, pull request or discussion for security problems.**

Report privately through either:

- GitHub private vulnerability reporting: the "Report a vulnerability" button under the repository's Security tab, or
- Email: [muballigh.shahid@gmail.com](mailto:muballigh.shahid@gmail.com) with the subject `cashfree_pg security`.

Please include the affected version, a description, and steps to reproduce. **Never include real credentials, customer data or production payloads.** Use sandbox values or redact them.

## What to expect

- Acknowledgement within 3 working days.
- An initial assessment within 7 working days.
- A fix and a coordinated disclosure date agreed with you. Credit is given unless you prefer otherwise.

## Scope

In scope: anything in this gem that could leak credentials or personal data, weaken webhook verification, send requests to an unintended host, cause duplicate charges or refunds, or mishandle amounts.

Out of scope: vulnerabilities in Cashfree's own services. Report those to Cashfree directly.

## If you leaked a secret

If you accidentally committed or posted a Cashfree client secret, rotate it immediately in the Cashfree merchant dashboard. Removing it from git history is not enough.
