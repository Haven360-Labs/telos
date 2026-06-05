# Contributing to Telos

Thank you for helping improve Telos. This project is open source under the [MIT License](LICENSE). Haven360 Labs maintains the repository; a Mac App Store release is planned but not yet available.

## Before you start

- Read [TRADEMARK.md](TRADEMARK.md) if you plan to **distribute** a fork (distinct name and icon required)
- For large changes, open an issue first to discuss approach
- Bug reports and small fixes are welcome via pull request

## Development setup

Requirements: macOS 14+, Xcode 15+.

```bash
git clone https://github.com/Haven360-Labs/telos2.git
cd telos2
open Telos.xcodeproj
```

Build from the command line:

```bash
xcodebuild -scheme Telos -configuration Debug build
```

See the [Developer guide](README.md#developer-guide) in the README for running the CLI-built app from DerivedData.

## Pull request checklist

- [ ] Builds cleanly: `xcodebuild -scheme Telos -configuration Debug build`
- [ ] You exercised the changed UI in the app (for UI changes)
- [ ] PR description explains **what** and **why**
- [ ] No unrelated formatting or drive-by refactors
- [ ] You agree your contribution is licensed under the project MIT license

## Code style

- Match existing Swift and SwiftUI patterns in the file you edit
- Prefer small, focused PRs over large rewrites
- Keep logic local-first; do not add required cloud or account dependencies without discussion

## Releases (maintainers)

Version tags are published on [GitHub Releases](https://github.com/Haven360-Labs/telos2/releases) when we cut a release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Then create a GitHub Release from that tag with user-facing release notes. When the Mac App Store build ships, App Store version numbers should match the Git tag when possible (e.g. `1.0.0` ↔ `v1.0.0`).

Attaching a built `.app` or `.dmg` to a release is optional until notarized distribution is set up.

## Security

If you find a security issue, please **do not** open a public issue. Report it privately via GitHub [Security Advisories](https://github.com/Haven360-Labs/telos2/security/advisories/new) if enabled, or contact the maintainers through a private channel listed on the repository.

## Questions

Open a [GitHub issue](https://github.com/Haven360-Labs/telos2/issues) for bugs, features, and general questions.
