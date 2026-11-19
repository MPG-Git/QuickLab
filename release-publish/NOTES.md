## Update for the lab

Close MATLAB, double-click **EEGLAB 2026**, and choose **Yes** when version 1.4.0 is offered. Existing installations keep their settings. First-time users can download **EEGLAB2026-Setup.exe** below; Windows and an installed MATLAB are required.

## What changed

- Restores useful Golden Old controls in plot windows: file/folder navigation, save-with-text, dataset information, component selection and removal, N-1 PCA, and figure export.
- Menus follow loaded-file, epoch, ICA and comparison availability. Multiple editors retain their data and marks. Component scrolling, ERP event selection and spectrum exports are corrected.
- Adds **QuickLab > Quick Channel Edit > REST / Infinity / Average (same leadfield)**, with independently computed native REST and FieldTrip Infinity results. Includes complete official REST dependencies, synthetic input datasets and example outputs. Click **Practice data** to run the examples.
- Updates the private error-report catalog for these sources; reporting remains optional.

## Tested package

The exact attached files passed upgrade and rollback from an unchanged 1.1.0 client, packaged MATLAB GUI checks, 29 MATLAB regressions, all 32 menu dependency checks, 16 updater checks, and 36 reporting/service checks. Live Supabase-to-private-GitHub delivery also passed.

[Detailed validation and artifact hashes](https://github.com/MPG-Git/QuickLab/blob/main/distribution/releases/1.4.0.md) | [Golden Old window/control inventory](https://github.com/MPG-Git/QuickLab/blob/main/docs/GOLDEN_LAYOUT.md)

The N3-specific batch script and participant recordings are not bundled. Experimental legacy forks and filename-based completion heuristics are excluded; every third-party scientific workflow and pixel-identical layouts are not certified.
