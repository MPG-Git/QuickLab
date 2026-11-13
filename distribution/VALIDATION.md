# Validation of the EEGLAB replacement build

## Desktop 1.2.0, 13 November 2026

Windows, MATLAB R2023b Update 3. Reproduced the 1.1.0 warning: both
FieldTrip-lite and Fileio provided an active `ft_defaults.m`. The new build
has exactly one initializer and retains Fileio's data readers/writers.
All 53 inventoried plugins plus EEG-BIDS registered. Every pinned version
matched EEGLAB's registration; startup contained no unknown versions,
folder/hook mismatches, false update offers, or FieldTrip path warning.
QuickLabMPG registered once with the existing QuickLab menu.

Passed: both installed synthetic examples; all 20 QuickLab regressions;
actual REST Infinity/Average cross-check (30 channels, four epochs, RMS
4.9011 microvolts; maximum REST disagreement 8.53e-14, maximum differential
voltage residual 7.47e-14); synthetic SET import through FieldTrip; SPM
26.10.01 synthetic NIfTI write/read and compiled Windows sampling.
SPM's native M/EEG initializer was also inspected: it introduces a separate
vendored FieldTrip, so that interface requires a separate clean MATLAB
session. It is not a supported same-session EEGLAB workflow.

The 16 updater checks, nine PowerShell reporting checks, 15 reporting-service
tests, and MATLAB privacy/consent/history/export checks passed. The 1.2.0
reporting catalog retains 1.1.0 compatibility. Repeat the release integration
checks using `distribution/tests/validate_release.m` in a fresh MATLAB session;
run the comparison suites from `tests` separately. These checks do not certify
every third-party algorithm, GPU configuration, or lab workstation.

Earlier release evidence follows; version choices and packaging details for
1.2.0 are in [VERSION_AUDIT.md](VERSION_AUDIT.md).

## Desktop installer and updates, 9 November 2026

The Windows desktop installer detects MATLAB and installs shortcuts without
command entry. Each managed installation/update runs the 53-plugin startup
check and both known-answer examples in MATLAB before activation.

The update contract suite passed **16 checks** under Windows PowerShell 5.1:
stable-version selection, prerelease exclusion, publisher URL/hash validation,
corrupt downloads, release mismatch, archive traversal, rollback/holdback,
concurrency locking, offline launch, failed-validation retention, successful
activation, and preservation of existing files. A real staged upgrade from a
local 1.0.0 test installation to a 1.0.1 fixture passed startup and both examples;
rollback selected 1.0.0 and retained both folders. These fixture versions were
not published as pretend releases.

Tests use an isolated MATLAB preferences directory because this test computer's
ordinary preferences file is corrupt. David's settings and hardware remain
untested. The GUI was inspected for readable layout and automatic MATLAB
detection; local backend and package validation are separate from a test on
David's machine. The installer is unsigned.

## EEGLAB and plugin validation

Checked 9 November 2026, Windows, MATLAB R2023b Update 3, EEGLAB 2026.1.0.

| Check | Result |
| --- | --- |
| Official release and 53 plugin downloads | ZIP integrity and SHA-256 recorded |
| Final installer | Passed under Windows PowerShell 5.1 |
| Startup inventory | 53/53 inventoried plugins registered; bundled EEG-BIDS also registered |
| Final launcher | One active EEGLAB root; QuickLab, ERPsource and TBT menu checks passed |
| Supplemental paths | MWF, SPM and PICARD resolve; FieldTrip-lite selected ahead of Fileio |
| Plugin startup errors | None with clean MATLAB preferences |
| Previously failing NeuroLode and ERPsource hooks | Both loaded successfully |
| QuickLab regression suite | 20/20 passed on EEGLAB 2026.1.0 |
| Installed QuickLab synthetic example | Passed; mean 2 µV, RMS 2.121320344 µV |
| Installed NeuroLode synthetic example | Passed; export error below 1e-6, centroids 10/15/20 Hz |
| REST Infinity versus Average calculation | Passed; overall RMS 4.9011112535494 |
| Independent REST versus FieldTrip reconstruction | Maximum error 8.5265e-14 |
| Between-channel voltage preservation | Maximum residual 7.4607e-14 |

The final installer was rerun into a new directory, excluding four legacy
QuickLab recordings outside its synthetic example. Its installed
`run_replacement_examples` entry point passed both examples. The example
plots and REST RMS plot were visually inspected.

The REST test uses 30 scalp channels and four epochs from EEGLAB's public
`eeglab_data_epochs_ica.set`, with REST's three-sphere/3,000-dipole leadfield.
It compares the official `rest_refer` result with REST_fieldtrip
`pop_refrefinf`, then verifies QuickLab's stored differences and plots. Its
runner is `tests/validate_infinity_average.m` in the QuickLab repository.
The runner now uses functions present in the official REST ZIP and distinguishes
FieldTrip from Fileio, which also ships a file named `ft_defaults.m`.

The initial test computer had a corrupt `matlabprefs.mat`, which prevented
MICROSTATELAB from loading. Repeating with a separate, clean preferences
directory resolved that environment failure without changing user preferences
or plugin source. A local Perl locale/path warning remained. Startup was tested
with real MATLAB figure support; EEGLAB's `getframe` startup cannot run under
`-noFigureWindows` in this environment.

## Desktop 1.1.0 error reporting

Checked 9 November 2026 with fabricated errors only:

- 15 Node checks passed, including signed GitHub OIDC validation and the actual
  PostgreSQL migration in PGlite (permissions, retries, leases and daily quota).
- 9 Windows PowerShell reporting checks passed; the 16 update regression checks
  also passed after adding the new payload files.
- Real MATLAB checks passed for redaction, consent, queue withdrawal, bounded
  history and manual export. A real desktop launch captured a fabricated runtime
  error through its timer and displayed both new menu items. The exported report
  omitted the fabricated private message.
- Live Supabase tables have RLS enabled; anonymous and authenticated roles have
  no read access or claim permission. The public health check succeeds and an
  unauthenticated claim returns 401.
- The hosted synthetic integration run delivered to a private GitHub issue,
  deduplicated a retried event, updated the same issue to two observations, and
  rejected an extra free-text field. GitHub run 42716686447 passed on private
  support commit c63c4b9. Its synthetic issue was marked and closed.

The deployed function imports service code and its allowlist from immutable
QuickLab commit `4cffd020a5e55a010a4dbe51d37875fff6a26095`.
Reporting coverage and retention limits are documented in
[REPORTING.md](desktop/REPORTING.md).

## What this does not establish

Plugin registration and these examples do not test all third-party algorithms,
every menu action, or scientific suitability for a study. CUDAICA's GPU/runtime
setup and 2026 GUI integration are unverified. AMICA/native executables,
device-specific importers, SPM analyses, and complete RELAX pipelines have not
been run as part of this installation test. MWF is included as a RELAX
dependency; MATLAB toolbox licenses and method-specific configuration remain
necessary. The exact version of David's old SPM and his unrecorded custom menu
edits cannot be determined from the log.

The NeuroLode synthetic workflow checks loading, export, continuous conversion,
and spectral centroids. Its full manual GUI/export/history checklist is not
completed by these automated checks. David's own recordings and computer were
not used. Keep the old application archived until his normal workflows pass
with the new installation.
