Restores the lab's familiar main-window arrangement from the May 2024 reference: **Adds to name**, **Save (+)**, the **New** suffix field, **Load Folder**, and the file selector. The filepath and ICA/rank information return to the dataset information area. Matching saved FFT pictures appear on the right. Previous/next controls appear when files are available, comparison commands appear after two datasets are loaded, and component displays require ICA.

Includes a synthetic FFT picture and generator so the lab can try the display immediately. Keeps the current EEGLAB core, Windows BINICA, Infinity/Average comparison fixes, all 53 inventoried plugins plus EEG-BIDS, tested updates, rollback, and optional private technical error reporting.

**Existing users:** close MATLAB, double-click **EEGLAB 2026**, and choose **Yes** when offered 1.3.1. No new download link or commands are needed.

**New users:** on Windows with installed, licensed MATLAB, download **EEGLAB2026-Setup.exe**, double-click it, and choose **Install and open EEGLAB**.

Validation: 29 MATLAB regression tests; real packaged GUI callbacks, scroll and component plots; original 1.1.0 updater to this exact package and rollback; all plugin registrations and synthetic examples; 290 plugin files verified against the pinned archive; live private Supabase-to-GitHub delivery. Native screenshot inspection of MATLAB was unavailable, and not every third-party scientific workflow is certified. The legacy unfinished-file/progress experiments and separate advanced editor are not blindly copied. See docs/GOLDEN_LAYOUT.md and distribution/releases/1.3.1.md.
