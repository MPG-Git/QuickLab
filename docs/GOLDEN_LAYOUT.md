# Familiar EEGLAB layout

The lab's May 2024 archive is the reference for the main-window arrangement.
Its working-tree `eeglab.m` and the QuickLab source in its saved Git history
were inspected locally. Recordings, local settings, Git configuration and
logs from that archive are not included in this release.

The maintained plugin adds these controls to the current EEGLAB core:

| Area | Familiar behavior |
| --- | --- |
| Bottom row | **Adds to name**, **Save (+)**, suffix field initially **New**, **Load Folder**, dataset selector |
| Dataset information | Separate filename and filepath lines; ICA component count and `Rank (N)` together |
| Right side | Matching `<dataset name>FFT.jpg` preview, when that image exists beside the `.set` file |
| Folder navigation | Dataset selector and previous/next arrows appear when matching files exist |
| Comparison menus | Both comparison commands appear once at least two nonempty datasets are in EEGLAB |
| ICA plots | Enabled after the current dataset has an ICA decomposition |

**Save (+)** saves a suffixed copy and asks before replacing an existing file.
Folder navigation retains unsaved data in EEGLAB's dataset list and does not
change MATLAB's working directory. Rank uses all samples and the maintained
numerical calculation. The Windows bundle continues to supply BINICA.

The existing QuickLab scroll, spectra, component and difference windows remain
available through **QuickLab > Quick Plots**. Existing processing fixes are
retained. This is not a replacement of the current core with the archived core.

Some archived experiments are not restored automatically: the unfinished-file
selector and progress pie inferred completion from DotLoc filename fragments;
the separate advanced editor had additional unvalidated processing code.
Their presence in the archive does not establish that those workflows work.
Saved MATLAB `.fig` files are not opened automatically as FFT previews.

## Try it with the supplied examples

1. Click **Load Folder** and choose this plugin's `examples/synthetic/data` folder.
2. Select `synthetic_rank3.set`. The information area should say `No; Rank (3)`;
   its supplied FFT picture appears on the right.
3. Enter a new suffix in **New**, then click **Save (+)** to save a copy.
4. Load both the supplied Infinity and Average examples. The comparison entries
   become available under **QuickLab > Quick Plots > Other**.
5. Run **Quick PCA > ICA** on `synthetic_rank3.set`. Expect three components;
   the ICA information becomes `3; Rank (3)` and component plots are enabled.

The `examples/synthetic/README.md` describes the expected numerical outputs.
`tests/validate_quicklab_controls.m` checks the zero-, one- and two-dataset
states, ICA state, save/reload, folder cancellation, boundary navigation,
unsaved-data retention, preview lifecycle and redraw/resize behavior using
synthetic data in a new folder.
