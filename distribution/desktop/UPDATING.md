# Publishing updates for desktop installations

Users install the EXE once. Their stable shortcuts select a validated version
and look for newer public releases in **MPG-Git/QuickLab**. Publishing an ordinary
commit or a release without a desktop update asset does not update their machine.
The mechanism covers this EEGLAB distribution, including the QuickLab and
NeuroLode commits pinned in its manifest. Other repositories and MATLAB itself
are not independently synchronized.

## Prepare a release

1. Finish and test the plugin changes in their source repositories. Update the
   distribution manifest to their immutable commit archive URLs, SHA-256 hashes,
   archive roots and package versions. Pin all changed third-party packages too.
   Do not point an installation manifest at a moving `main` ZIP.
2. Increase `desktop/release.json`'s three-part version and matching
   `eeglab-desktop-vX.Y.Z` tag. Every published version is immutable: corrections
   get a higher version. Keep schema version 1 unless a compatible migration is
   implemented and tested.
3. Run `tests/Test-DesktopUpdates.ps1` under Windows PowerShell 5.1. Build with
   `Build-DesktopInstaller.ps1 -OutputDirectory <new-folder>`. This creates the
   single EXE and `EEGLAB2026-Update.zip` from the same source payload.
4. Test the built payload into an isolated installation, including actual
   MATLAB startup, the two synthetic examples, upgrade, failed-update retention,
   offline launch and rollback. Review algorithm changes with appropriate
   scientific tests; the installation examples are not comprehensive validation
   of every plugin. Record actual results in `distribution/VALIDATION.md`.
5. Commit and push the tested sources. Create a **draft** GitHub release for
   the matching desktop tag and commit. Upload both build artifacts, then
   publish it as a stable release. GitHub must report the update ZIP's
   `sha256:...` asset digest. Drafts, prereleases, missing hashes, and release
   assets outside this repository are ignored by the client.
6. Download the public artifacts anonymously and verify their hashes. Test
   that an older-version fixture discovers and verifies the published package.
   Do not publish test versions merely to exercise update discovery.

No download account or credential is installed on the user's computer. The
initial EXE is unsigned; code signing is a separate distribution improvement.
The update digest is verified against GitHub's HTTPS API, not a claim of an
independent code-signing identity.

## Operational behavior

Managed files live below `%LOCALAPPDATA%\MPG\EEGLAB`. `state.json` selects the
current and previous version; its replacement is atomic and keeps a backup.
Every candidate installs in a separate folder under `versions`. Its startup
and synthetic examples must pass before switching that pointer. Changes never
patch the files of a running MATLAB session. The package cache is addressed by
hash so new plugin versions do not collide with old downloads.

The launcher asks before an update, with a one-day deferral when declined.
Network/API errors fall back to the installed version. A rollback selects the
previous validated folder and holds back the rejected release until a newer
one is published. Logs are local; the updater transmits no recordings or logs.

The update worker is separate from the progress window so long downloads and
MATLAB checks do not block the window's UI. An installation lock prevents two
launchers from changing the active pointer simultaneously. Interrupted and
failed candidates are retained for diagnosis; there is no automatic recursive
cleanup of old versions or user files.
