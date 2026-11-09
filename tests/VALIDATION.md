# Infinity / Average comparison validation

Run date: 7 November 2026. MATLAB R2023b Update 3.

| Check | Result |
| --- | --- |
| Regression suite against EEGLAB 2020.0 | 17 / 17 passed |
| Regression suite against EEGLAB 2024.2 | 17 / 17 passed |
| Actual REST Infinity versus Average comparison | Passed |
| Source | EEGLAB `sample_data/eeglab_data_epochs_ica.set` |
| Compared data | 30 scalp channels, 4 epochs, 1,536 samples per channel |
| Infinity calculation | `pop_refrefinf(EEG, 'infinity')`, REST_fieldtrip 1.0 and FieldTrip 20250915, with the REST 1.2 three-sphere / 3,000-dipole leadfield |
| Average calculation | EEGLAB `pop_reref(EEG, [])` on the same input |
| Observed overall RMS difference | 4.9011112535494 stored amplitude units |
| Maximum difference between FieldTrip Infinity and independent `dong_rest_refer` calculation | 8.5265e-14 |
| Maximum change in between-channel voltages after removing the common reference offset | 7.4607e-14 |

The numerical checks verify that the comparator reports the actual stored
Infinity-minus-Average values, including the mean offset. They do not establish
the accuracy of a particular head model or reference estimate for research data.

The integration test also verified the exact data stored by the overlay and
difference viewers, disabled mean subtraction, unchanged inputs, the original
last-minus-previous calling convention, and reordered channel matching. The
three exported comparison plots were visually inspected.

The runner explicitly verifies that it is testing this repository's
`plotDifference.m`, rather than another installed QuickLab copy. Tests require
no patient data and save no EEG datasets. The tested environments emitted an
existing local MATLAB preferences warning; all numerical and graphics checks
completed successfully. FieldTrip also reconstructed sample information for
the sample epochs; the test preserves their original stored order.

Real-user recordings and a mixed EEGLAB 2024/2026.1.0 installation were not
directly tested.
Run `run_quicklab_tests` and `validate_infinity_average` as described in the root
README to reproduce these results with a local installation.

## Startup follow-up, 9 November 2026

MATLAB R2023b Update 3: the expanded suite passed **20/20 tests with EEGLAB
2024.2 and 20/20 with EEGLAB 2020.0**. The plugin hook now returns its existing
version as text, supports a version-only query, and does not duplicate its
tagged menu when called again. Both comparison menu callbacks remain unchanged.

The new read-only setup report detected two fixture EEGLAB roots and two
QuickLab hook files in separate plugin folders, including folders not on the
MATLAB path. The test hooks deliberately error if executed; inspection completed
without executing them. Tests also verified unchanged paths, current folder,
and figure state.

The shipped synthetic Infinity/Average example was rerun with EEGLAB 2024.2.
Its reference comparisons passed: mean difference 2 microvolts and RMS
2.12132034355964 microvolts. The comparison implementation and synthetic input
files were unchanged. The real-REST integration results above remain the
7 November run, not a new test of a user's full plugin collection.
## Replacement installation, 9 November 2026

The same 20-test suite also passed with official EEGLAB **2026.1.0**. The actual
REST Infinity/Average integration passed with the catalog REST 1.2 ZIP and
FieldTrip-lite 250523: overall RMS 4.9011112535494, independent REST maximum
error 8.5265e-14. The integration runner now uses `dong_calc_leadfield3` and
`rest_refer`, which are present in that ZIP, and selects FieldTrip using its
source-analysis entry point so Fileio's `ft_defaults` is not mistaken for it.

Both installed synthetic examples passed after loading the complete plugin
collection. See [distribution validation](../distribution/VALIDATION.md) for
startup coverage and remaining third-party/hardware/manual workflow limits.
