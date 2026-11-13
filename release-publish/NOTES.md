Restores QuickLab's **Save (+)** button, filename addition, **Load Folder**, **Previous/Next**, dataset selector, and rank/component display.

Includes the official Windows **BINICA** executable and required OpenBLAS library, with source and license. Normal QuickLab ICA uses bundled BINICA; MATLAB runica is also available. No separate binary installation or commands are needed. Rank-aware ICA/PCA supports Average-referenced/interpolated data, and the full ICLabel/component display runs on the MATLAB client.

Also fixes the high-pass menu, removes developer-specific DipFit paths, and includes a new synthetic ICA dataset with example outputs. All 53 inventoried plugins plus EEG-BIDS remain included. FieldTrip/version-label fixes and optional private error reporting are retained.

**Existing users:** close MATLAB, double-click **EEGLAB 2026**, and click **Yes** when offered 1.3.0. Click **Practice data** to run the bundled comparison, ICA and NeuroLode checks. If an older updater cannot download the package, download **EEGLAB2026-Setup.exe** below and run it once.

**New users:** use Windows with installed, licensed MATLAB. Download **EEGLAB2026-Setup.exe**, double-click it, and choose **Install and open EEGLAB**.

Validation: 29 MATLAB regression tests; real GUI callbacks; 29-channel/rank-25 BINICA; default ICA/ICLabel/component display; 31/31 QuickLab menu dependencies; exact update from 1.1.0 and rollback; all plugin registrations and synthetic examples; private Supabase-to-GitHub reporting. Tested on MATLAB R2023b Update 3. Specialized methods can require licensed MATLAB toolboxes or compatible GPU hardware. Anatomical fitting and every third-party scientific workflow are not certified. See distribution/releases/1.3.0.md and distribution/VALIDATION.md.
