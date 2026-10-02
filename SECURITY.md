# Security policy

## Supported versions

Only the [latest release](https://github.com/vanisov/sonar/releases/latest) gets security fixes.

## Reporting a vulnerability

Please don't open a public issue. Use [Report a vulnerability](https://github.com/vanisov/sonar/security/advisories/new)
on the Security tab instead, which keeps the report private until it's fixed.

Include what you found, how to reproduce it, and which version you tested. Expect a reply within a week.

## What's in scope

Sonar runs without admin rights and makes one network request: the opt-in update check. The parts that matter most:

- **The updater:** downloading, verifying, and replacing the app.
- **Ending processes:** Quit, Force Quit, End and Force End on the Processes page.
- **Clean Up:** anything that could move files outside the folders it lists, or files the user didn't pick.
