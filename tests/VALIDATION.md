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

David's actual files and EEGLAB 2021 installation were not directly tested.
Run `run_quicklab_tests` and `validate_infinity_average` as described in the root
README to reproduce these results with a local installation.
