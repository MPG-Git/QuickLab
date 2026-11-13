# QuickLab for EEGLAB

The plugin is in `QuickLab_11.12.21_NL`. The November 2026 comparison update
restores **Plot Last Files Data Differences** and adds a chooser for comparing
stored Infinity- and Average-referenced versions of the same recording.

For a fresh replacement installation, use the [EEGLAB 2026.1.0 installer](distribution/README.md).
The desktop installer finds MATLAB, creates shortcuts, and checks GitHub for
tested updates. Updates are validated before activation, with a previous-version
shortcut for rollback.
Desktop version **1.2.1** adds automatic update-failure details: failed step,
component, native codes, software environment, plugin validation failures and
safe code locations. With reporting enabled, sending starts before the error
dialog and does not require MATLAB to open. It retains the 1.2.0 fixes for the FieldTrip startup warning and misleading
plugin update labels, identifies our maintained edition as QuickLabMPG 1.0.0,
and updates SPM to 26.10.01. Existing users can close MATLAB, open the
**EEGLAB 2026** shortcut, and click **Yes**. It also provides **Get error report**
and optional private technical reporting. Lab members need no GitHub or Supabase account. See the
[reporting details and limits](distribution/desktop/REPORTING.md).
It downloads all 53 plugins from the supplied startup inventory, consolidates
duplicates, and includes the QuickLab/NeuroLode synthetic examples. See its
[inventory](distribution/PLUGIN_INVENTORY.md) and [validation limits](distribution/VALIDATION.md).

## Install or update

1. Download this repository using **Code > Download ZIP**, or pull the latest
   `main` in your existing checkout.
2. Close EEGLAB. Back up your current QuickLab plugin folder.
3. For a new installation, copy `QuickLab_11.12.21_NL` into EEGLAB's `plugins`
   folder and rename it `QuickLabMPG1.0.0`. Keep only one active QuickLab installation on the MATLAB path. This identifies the maintained lab edition separately from the historical catalog plugin.
4. For a customized **QuickLab GUNN** installation, copy just the updated
   `plotDifference.m` into its existing plugin folder. This preserves your
   customized menu and fixes callbacks that call `plotDifference(ALLEEG)`.
   The chooser is also available from the command line, as shown below.
   Updating `eegplugin_QuickLab.m` adds the new chooser menu, but replaces any
   local menu customizations; merge its two comparison entries if needed.
5. Restart EEGLAB. Check which helper is active:

   ```matlab
   which plotDifference -all
   ```

The first path must be the updated helper in the intended QuickLab folder.
The comparator requires MATLAB and EEGLAB. REST and FieldTrip are only needed
to **create** Infinity-referenced data or run the integration test; the
comparator reads reference versions that have already been computed.

If startup lists multiple EEGLAB installations or repeated QuickLab plugins,
follow the [setup troubleshooting guide](SETUP_TROUBLESHOOTING.md). The included
`quicklab_setup_report` inspects paths and plugin folders without changing them.

## Compare Infinity and Average

Load both versions into EEGLAB and keep both in the **Datasets** list. Use
versions of the same recording with the same retained samples and epochs.

Select **QuickLab > Quick Plots > Other > Compare Datasets (Infinity / Average...)**,
then select exactly two datasets. Their names and stored reference labels are
shown. In the chooser, A is the selected entry with the lower dataset index
and B is the other selected entry. Each plot identifies both datasets.

With an existing customized menu, open the same chooser using:

```matlab
plotDifference(ALLEEG, 'select');
```

The existing **Plot Last Files Data Differences** action compares the last
occupied dataset minus the previous occupied dataset, preserving the original
subtraction order. Empty dataset slots are skipped. To explicitly obtain
Infinity minus Average, specify their dataset indices in that order:

```matlab
% Example: Infinity is dataset 3, Average is dataset 2.
[report, figures] = plotDifference(ALLEEG, [3 2]);

% The original two-dataset calling convention is also supported.
[report, figures] = plotDifference(EEG_infinity, EEG_average);

% Statistics only, without opening figures:
report = plotDifference(ALLEEG, [3 2], false);
```

The comparison opens:

- An overlay: A in blue and B in red.
- A signed difference scroll plot: A minus B.
- A per-channel RMS difference chart, calculated across all retained samples
  and epochs. A MATLAB table also reports mean and maximum absolute differences.

Values use the original stored amplitude units. Channel means are retained,
so DC differences remain visible. The helper does not re-reference, filter,
resample, truncate, or modify the input datasets. Use the figure menus to
save or print plots.

Channel labels are matched even when channel order differs. Incompatible
channel sets, timing, event identities, and available epoch identities produce
an error instead of an invalid subtraction. If both datasets lack channel
labels or events, a warning identifies which alignment checks are unavailable.
Matching metadata alone cannot establish that two files contain the same
recording; select corresponding versions of the same retained data.

## What was fixed

The old helper called `eegplot_w`, which is absent from this repository. It also
used metadata from the first dataset regardless of which datasets it compared,
and its title said "PRE MINUS POST" while calculating the opposite order.
The replacement uses EEGLAB's standard `eegplot`, the selected datasets'
metadata, and explicit A/B labels. The updated menu no longer calls `eeg_store`
after a read-only comparison.

## Validation

On 7 November 2026, all **17 regression tests passed with EEGLAB 2020.0 and
2024.2**, running MATLAB R2023b Update 3. Tests cover reference offsets, signs,
the legacy two-struct API, single-precision and epoched data, reordered channels,
empty dataset slots, disk-backed `.fdt`/`.set` data, incompatible inputs,
nonfinite samples, figures, and menu callbacks.

An integration test used the real EEGLAB sample recording, 30 scalp channels
(EOG excluded), and four epochs. It compared actual REST Infinity output
against `pop_reref(EEG, [])` Average output. The test checked statistics,
the arrays passed to both viewers, retained means, unchanged inputs, and
channel reordering. See [the validation record](tests/VALIDATION.md).
Real-user recordings and the mixed EEGLAB 2024/2026.1.0 installation described
in a startup log have not been directly tested.

On 9 November 2026, all **20 current tests passed with EEGLAB 2020.0 and
2024.2**. Added checks cover textual plugin version reporting, repeated menu
initialization, and read-only detection of duplicate EEGLAB roots and QuickLab
plugin folders. The bundled Infinity/Average example also passed again.

To reproduce the regression tests:

```matlab
addpath('path/to/QuickLab/tests');
run_quicklab_tests('path/to/eeglab');
```

To reproduce the actual Infinity/Average test, install REST 1.2, REST_fieldtrip,
DIPFIT, and FieldTrip under EEGLAB's `plugins` folder, retain EEGLAB's sample
data, and run:

```matlab
validate_infinity_average('path/to/eeglab', 'path/to/validation-output');
```

This generates comparison PNGs, a statistics CSV, and a JSON result summary.
It does not write or change EEG datasets.

## Downloadable synthetic example

[Run the bundled synthetic example](QuickLab_11.12.21_NL/examples/synthetic/README.md) to check your setup against
included reference outputs. It contains actual input files, a one-command runner,
expected tables/plots, and numerical comparisons that report PASS or a mismatch.
The example guide links to the main-branch ZIP, including the readiness fixes.

See the [download index for all eight neuroscience examples](SYNTHETIC_EXAMPLES.md)
for the companion tools, setup requirements, and expected results.
