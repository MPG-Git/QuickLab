## EEGLAB Desktop 1.4.1

**Existing users:** save your work, close MATLAB, double-click **EEGLAB 2026**, and choose **Yes** for the available update. The older launcher's first prompt may not show a version number. No installer download is needed when the managed launcher can reach GitHub.

After this update:

- Prompts show installed and available versions.
- Failed update checks retry using a second HTTPS route outside GitHub API rate limits. If both routes remain unavailable, the launcher shows Retry / Cancel instead of silently opening an old version.
- No postpones only this launch. Rollback protection remains in place.
- **Updates (1.4.1) > Check for updates** checks from inside EEGLAB without closing the working session. After installation, save your work, close MATLAB and reopen the desktop shortcut.
- Fixes false update failures caused by Windows PowerShell losing the child process exit code.
- Registers installed plugins even when EEGLAB's remote plugin catalog is unavailable.

QuickLab, REST/Infinity comparison and practice examples are retained from 1.4.0. Source pins and scientific algorithms are unchanged.

[Validation, exact artifact hashes and publication status](https://github.com/MPG-Git/QuickLab/blob/main/distribution/releases/1.4.1.md)

A shortcut to an unrelated EEGLAB installation does not receive these updates. Use the managed **EEGLAB 2026** shortcut.

Automatic updates do not depend on the reporting service. The service currently recognizes 1.4.0; 1.4.1 technical reports stay queued locally and retry automatically until its catalog is updated, within the existing 30-day retention. Report delivery for 1.4.1 is pending; software installation and update discovery are verified.
