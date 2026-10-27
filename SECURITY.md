# Security

## What Auxo stores

- **Accounts, settings and fetched activity**: JSON files in the app's App Group container on your device.
- **GitHub token**: the Keychain only, never in files or logs. Auxo requests no GitHub permissions; the token can read public profile data.

Auxo has no servers and sends nothing anywhere except requests to GitHub, LeetCode and Codeforces for the accounts you add.

## Reporting a vulnerability

Please don't open a public issue for security problems. Use GitHub's private reporting instead: go to the **Security** tab of this repository and choose **Report a vulnerability**.

Include what you found, how to reproduce it, and its impact. You'll get a reply as soon as possible.
