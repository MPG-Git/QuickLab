# Version audit — 13 November 2026

Desktop **1.3.0** uses **EEGLAB 2026.1.0**, the newest ZIP listed by the
[official publisher](https://sccn.ucsd.edu/eeglab/download/daily/).
All 49 catalog-managed plugins from the 53-plugin inventory match the
[current stable EEGLAB catalog](https://sccn.ucsd.edu/eeglab/plugin_uploader/plugin_list_all.php).
The additional bundled EEG-BIDS 10.5 also matches the catalog.
FieldTrip-lite 250523 and Fileio 260210 are the current EEGLAB catalog packages;
development/nightly snapshots of the full FieldTrip toolbox are not substituted.

The four separately maintained entries are:

| Component | Selected source | Check |
| --- | --- | --- |
| QuickLab lab edition | MPG-Git/QuickLab, `acc856281a15865e587987641c54aa82d2ac68ec`, version 1.1.0 | This release's maintained comparison/menu code; registered as QuickLabMPG |
| NeuroLode | MPG-Git/NeuroLode, `0fc194d44330ba975346c3457da56d1fb00bce47` | Current main; hook 1.7.0 |
| CUDAICA for Windows | CloudyDory/cudaica_win, `02aaf9c36c0b12346bccdc25eec195565634abdd` | Current upstream HEAD; 1.1; GPU execution unverified |
| SPM | [Official MATLAB release 26.10.01](https://github.com/spm/spm/releases/tag/26.10.01) | Newest non-prerelease; replaces SPM12 r7771 |

RELAX's supplemental MWF dependency remains at current upstream HEAD
`85115641b36b711a4263eeb83f60e4706ea4e732` in exporl/mwf-artifact-removal.
The [manifest](manifest.json) contains archive URLs and SHA-256 checksums.
Current means the published sources checked on this date, not every upstream
development branch or every possible EEGLAB extension.

## Packaging adaptations

- Versioned folders supply missing metadata for AAR, Adjust, MARA, TBT,
  automagic, erppeakinterval, fullRankAveRef, std_dipoleDensity and trimOutlier.
- EYE-EEG's official 1.0.1 archive says `1.01` in its hook; the installer
  corrects that exact string, refusing an unexpected source/version.
- Fileio's `ft_defaults.m` is excluded because the complete FieldTrip-lite
  initializer is present. Every Fileio import/export function is retained.
  No warnings or upstream update checks are disabled.
- The lab fork has a distinct catalog identity, QuickLabMPG, while preserving
  the QuickLab menu and Infinity/Average comparison.

SPM's native M/EEG initializer adds its separate vendored FieldTrip and must
run in a separate clean MATLAB session. Its complete M/EEG workflow has not
been validated in this bundle. See [validation](VALIDATION.md) for test scope.

The supplemental Windows BINICA runtime is pinned to official SCCN commit `ec0004fd64213ca51290eff38636237e706b38b5` (no tagged releases published). The EXE and adjacent OpenBLAS DLL were exercised on full- and reduced-rank synthetic data; user setup of `icadefs.m` is unnecessary for QuickLab.
