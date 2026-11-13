Existing users: close MATLAB, double-click the **EEGLAB 2026** desktop shortcut, and click **Yes** when the update is offered. Keep the updater open while it installs and checks the new version. No new download link or typed commands are needed.

New users: download **EEGLAB2026-Setup.exe** below, double-click it, and choose **Install and open EEGLAB**. Windows and installed, licensed MATLAB are required.

This update fixes the FieldTrip startup warning by removing the duplicate Fileio initializer, corrects missing/mismatched plugin version labels, and preserves our customized comparison as **QuickLabMPG 1.0.0** with the familiar **QuickLab** menu. It no longer offers the older stock QuickLab as an update to our edition.

The official stable releases were audited on 13 November 2026. EEGLAB 2026.1.0, all 49 catalog-managed entries and bundled EEG-BIDS are current in the official catalog. SPM is upgraded to **26.10.01**; our lab plugins and the current Windows CUDAICA/MWF sources remain pinned and checksummed. [Version audit](https://github.com/MPG-Git/QuickLab/blob/main/distribution/VERSION_AUDIT.md).

Tested: all 53 plugin registrations, both synthetic examples with expected outputs, 20 QuickLab regressions, the actual Infinity/Average REST comparison, Fileio import, SPM NIfTI/MEX, a real 1.1.0-to-1.2.0 upgrade and rollback, and live private error-report delivery. Optional reporting and the **Practice data** / **Get error report** controls remain available.

SPM's native M/EEG interface needs a separate clean MATLAB session because it adds its own FieldTrip. Full third-party analyses and GPU configurations are not certified by these checks. The initial installer remains unsigned. [Validation and SHA-256 hashes](https://github.com/MPG-Git/QuickLab/blob/main/distribution/releases/1.2.0.md).
