Update failures now send actionable technical details automatically when error reporting is enabled: failed step and component, Windows/HTTP/process codes, MATLAB identifiers and shipped-code locations, plugin startup checks, software builds and available disk space.

The sender starts before the error dialog and does not need MATLAB to open. Failed MATLAB validation candidates can report before activation. Offline reports remain queued. Existing reporting choices are honored; no GitHub or Supabase account is needed. Raw logs, personal paths, recordings and arbitrary error-message text are not uploaded.

**Existing users:** close MATLAB, double-click **EEGLAB 2026**, and click **Yes** when offered 1.2.1. Keep **Error reporting settings → Yes, allow** enabled. If the old updater cannot reach the new package, download **EEGLAB2026-Setup.exe** below and double-click it once.

**New users:** Windows and installed, licensed MATLAB are required. Download **EEGLAB2026-Setup.exe**, double-click, then choose **Install and open EEGLAB**.

All 53 inventoried plugins, bundled EEG-BIDS, synthetic data and examples remain included. Versions and algorithms are unchanged from 1.2.0. This update improves diagnosis; it does not claim to fix every existing installation problem.

Validation: original 1.1.0 client upgraded and rolled back; all registrations and both examples passed in MATLAB R2023b Update 3. Passed 18 Windows reporting checks, 16 updater checks, real worker/MATLAB failure capture, 18 Node/PostgreSQL/OIDC checks, and live Supabase/private GitHub delivery. See distribution/releases/1.2.1.md for artifact hashes and evidence.
