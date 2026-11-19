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

## Plot-window audit (Desktop 1.4.0)

The audit compared all 164 recovered top-level QuickLab MATLAB sources,
active menu labels/callbacks and figure controls against the archived branch
`b9a0ae2f233ec698843bb8d2554e8a88f3255465`. The maintained EEGLAB core stays current.

| Archived area | Maintained behavior |
| --- | --- |
| Adv. Data Editor | Restored familiar menu entries; uses the maintained scroll engine |
| Editor information | Channels/reference, samples/rate, epochs/events, time range, ICA/rank above traces |
| Editor folder selector | Load Folder and Load File From This Folder; opens a second editor and retains the first window's unsaved marks |
| Editor saving | Save File with Text and Store Marks to EEGLAB; saving asks before overwriting; storing adds a dataset |
| Editor modes and processing | Existing channel/component switch, epoch/continuous display, interpolation/rejection, method selector, Run/Apply, Undo/Redo, Clear Marks, scale and navigation controls retained |
| Editor menus | Scoped QuickLab file/plot actions; Figure/Display/Settings/Events controls retained |
| Spectra | Familiar FFT(avg) action and Save Figure; export uses the plotted dataset's filename and asks where to save |
| Component overview | Select All, Clear Values, component details, component scroll, CorrMaps, rejection list, removal and N-1 PCA retained; callbacks now use the plotted decomposition |
| ERP overview | Familiar alias restored; enabled for epoched data with ICA; cancellation stops cleanly; selected event types are passed correctly |
| Defaults | Edit QuickLab Defaults restored (opens the installed defaults file) |
| Differences | Last-files and selectable-dataset comparisons remain available after two datasets are loaded |

Closing an editor no longer reloads a basename from the current working folder.
Store Marks and component changes create a new EEGLAB dataset, retaining the
previous active dataset. Selecting another file keeps the original editor open.
These explicit actions can therefore add several datasets to the Datasets menu.
The archived practice of copying every EEGLAB menu into a plot was replaced by
actions bound to that plot, preventing edits to a different active dataset.

The unfinished-file selector and progress pie inferred completion from DotLoc
filename fragments; these heuristics and unused experimental processing forks
are not restored. The advanced editor's useful controls are incorporated above.
Saved MATLAB `.fig` files are not opened automatically as FFT previews.

The shared-leadfield REST/Infinity comparison is under **QuickLab > Quick Channel
Edit > REST / Infinity / Average (same leadfield)**. It creates three new datasets
without changing the input. Select scalp channels with one original reference
and valid head-centered EEGLAB XYZ coordinates. Excluded auxiliary channels stay
unchanged; stale ICA/source estimates are cleared. The standard three-sphere
model projects electrode directions to the scalp and is not a subject-specific
head model. The separate N3 batch script is not distributed; its shared-model
approach is available through this portable function and menu.

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
