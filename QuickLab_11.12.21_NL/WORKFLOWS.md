# QuickLab lab edition 1.1.0

The desktop package includes the lab's QuickLab controls and Windows BINICA.
Install the managed desktop update to get the executable and its OpenBLAS
library automatically. The ordinary plugin download also works with EEGLAB's
included MATLAB `runica` when the Windows binary is unavailable.

## Save and browse

The bottom of the EEGLAB window has **Add to filename**, **Save (+)**,
**Load Folder**, **Previous**, **Next**, and a dataset selector. Choose a
folder, then select a `.set` file. Add a suffix such as `_clean` before saving
to keep your original. Replacing an existing dataset requires confirmation.
Unsaved changes are retained as datasets in the current EEGLAB session when
you navigate. They still need to be saved before closing MATLAB.

The folder path and a centered data-rank estimate appear below the parameter
table. **ICs** is the number of existing ICA components. Average referencing
and interpolation can make rank smaller than channel count.

## ICA/PCA

**QuickLab > Quick PCA > ICA** uses the bundled Windows BINICA when available;
otherwise it announces and uses MATLAB `runica`. Both use Extended Infomax.
Explicit **Windows BINICA** and **MATLAB runica** choices are also available.
BINICA runs in a temporary folder, supports installation paths with spaces,
and needs no manual `icadefs.m` edits or command-window setup.

Automatic dimension selection uses all samples of centered data in double
precision, with EEGLAB's covariance threshold of `1e-7` in squared microvolts
(or a larger numerical-roundoff floor for very large values). Data must be
in EEGLAB's normal microvolt units. The estimate is a numerical aid, not a
claim that every component represents an independent brain source.
An explicit PCA count cannot exceed the estimated rank. **N-1 PCA** uses the
previous component count, bounded by the current rank, even when `icaact`
is empty. Marked components are never silently removed before a new run:
reject them explicitly using the component-rejection workflow first.

## Practice and requirements

Click **Practice data** in the desktop build to run comparison, ICA and
NeuroLode examples. The ICA folder contains synthetic input/output `.set`
files and `ica_metrics.csv`: four channels, rank three, three components,
and relative reconstruction error below `1e-5`. Different ICA implementations
can return different component order, signs, scales and weights; these are
not required to match the example exactly.

**QuickLab > Check QuickLab setup** checks the active menu functions, the
Windows binary and MATLAB toolbox licenses. Specialized third-party methods
can require licensed Signal Processing, Statistics or Parallel Computing
Toolboxes; CUDA methods additionally require compatible GPU hardware. These
commercial licenses and hardware cannot be supplied by the plugin installer.
Passing setup checks does not certify every third-party analysis workflow.

The bundle uses the [official SCCN BINICA source and Windows runtime](https://github.com/sccn/binica/tree/ec0004fd64213ca51290eff38636237e706b38b5),
with its license and corresponding source included under `dependencies/BINICA`.
