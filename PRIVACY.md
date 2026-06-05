# Telos Privacy Policy

**Effective date:** June 5, 2026  
**Controller:** Haven360 Labs

Telos is a local-first macOS app. Your planning data stays on your device by default.

## Summary

- No account is required to use Telos
- Tasks, notes, and projects are stored **locally** on your Mac
- We do **not** sell your personal data
- We do **not** use third-party advertising or analytics in the app today
- Optional **iCloud backup mirroring** uses **your** Apple iCloud account and Apple’s infrastructure when available

## Data stored on your device

Telos stores your data locally using SwiftData, including:

- Daily plans, tasks, and subtasks
- Notes and retrospectives
- Projects, goals, challenges, and related metadata
- Time-tracking records
- App preferences (notification times, streak history, UI settings, and similar)

Primary storage location:

`~/Library/Application Support/com.telos.app/`

Local automatic backups may be kept under:

`~/Library/Application Support/com.telos.app/Backups/`

## Data you control

You can:

- **Export** tasks and notes to CSV from the app
- **Back up and restore** locally from Settings
- **Delete** data by removing the app and its Application Support folder

## iCloud (optional)

If you are signed into iCloud and the build supports it (requires an Apple Developer Program setup with the iCloud capability), Telos may **mirror backups** to your iCloud Drive under your Apple account. This uses [Apple’s privacy policy](https://www.apple.com/legal/privacy/). Haven360 Labs does not operate backup servers.

**Planned for official releases:** iCloud sync across Macs via Apple CloudKit in your private iCloud database. Sync is not available in the current open-source build.

Community builds compiled without Haven360 Labs’ Apple Developer entitlements may not include iCloud backup or sync.

## Notifications

Telos may request permission to send **local notifications** (morning review reminders, end-of-day reminders, and timer completion). Notification content is generated on your device; we do not send push notifications from our servers.

## Data we do not collect

Telos does **not** currently:

- Collect usage analytics
- Send crash reports to Haven360 Labs servers
- Require registration or email to use core features

If we add optional telemetry or crash reporting in the future, we will update this policy and describe it in the app before collection.

## Children

Telos is not directed at children under 13. We do not knowingly collect personal information from children.

## Changes

We may update this policy. We will revise the “Effective date” above and note material changes in release notes.

## Contact

Questions about this policy: open a [GitHub issue](https://github.com/Haven360-Labs/telos/issues) or contact Haven360 Labs through the repository.

---

*Unofficial community builds are not operated by Haven360 Labs.*
