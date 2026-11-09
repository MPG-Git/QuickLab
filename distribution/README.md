# EEGLAB replacement installation

This Windows installer downloads official EEGLAB 2026.1.0 and all 53 unique
plugin names from the supplied November 2026 startup inventory. It uses one
QuickLab and one DIPFIT installation. Official bundled EEG-BIDS is also retained.
The MWF dependency needed by RELAX is downloaded separately and added by the launcher.
MATLAB is required; this is not the compiled EEGLAB application.

The official release ZIP is newer than the tags returned by GitHub during
verification on 9 November 2026. Sources and SHA-256 checksums are pinned in
`manifest.json`. Third-party packages come directly from their publishers;
their own licenses and dependencies apply. No personal EEG recordings are used.
Legacy QuickLab `.set`/`.fdt` files outside its synthetic example are excluded
from the installation; official publishers' sample/template data are retained.

## Install in a new folder

Download this QuickLab repository ZIP, extract it, and open PowerShell in its
`distribution` folder. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-EEGLAB.ps1 -Destination C:\EEGLAB_2026_New
```

The process downloads approximately 1 GB and needs additional disk space to
extract it. Keep the terminal open until it reports completion. It refuses to
overwrite an existing destination. A partial installation has no `COMPLETE.json`;
choose another new destination when retrying. Downloads are cached under
`%LOCALAPPDATA%\EEGLAB-download-cache` and verified before reuse.

Start a **new MATLAB session**, change its Current Folder to
`C:\EEGLAB_2026_New`, then run:

```matlab
[ALLEEG, EEG, CURRENTSET, ALLCOM] = start_eeglab_replacement;
report = check_eeglab_replacement;
```

The launcher uses MATLAB's default path plus this installation for the session.
It enables the full EEGLAB menus so TBT's legacy rejection menu is available,
and selects FieldTrip-lite ahead of the smaller Fileio copy of `ft_defaults`.
It does not save the path or delete the old installation. Do not use “Add with
Subfolders” on EEGLAB. Once this build passes your normal workflows, archive the
old installation and remove its entries from MATLAB startup scripts/saved paths.
Keep your recordings separately from application folders.

## Synthetic examples

QuickLab and NeuroLode include small synthetic datasets, reference outputs,
verification scripts and README files under their `examples/synthetic` folders.
Follow those READMEs to reproduce and compare results. Other plugins retain
whatever examples their official packages provide; a synthetic test of every
third-party algorithm has not been supplied or claimed.

After launching this installation, run both examples together:

```matlab
run_replacement_examples;
```

Results go into a new `example_run` folder. Both examples must print `PASS`.
QuickLab should report a mean difference of 2 microvolts and RMS difference
of 2.121320344 microvolts per channel. NeuroLode should recover spectral
centroids of 10, 15 and 20 Hz. Each result folder contains its comparison
report and `PASS.txt`; QuickLab also produces comparison plots.
The comparison menu in this build is **QuickLab > Quick Plots > Other**;
older example text may refer to the customized "QuickLab GUNN" label.

## Coverage and limits

Installing all plugin folders is distinct from testing every workflow. See the
validation report in this directory for the actual checks and limitations.
CUDAICA requires a supported NVIDIA GPU and compatible CUDA/Intel runtime
libraries. Its upstream GUI replacement files stop at older EEGLAB versions;
this installer preserves the 2026 core instead of overwriting `pop_runica`.
The `cudaica` command is installed, but GPU execution and its ICA menu
integration have not been validated. SPM12 r7771 is selected because the old log gives no SPM version.
QuickLab uses the tested MPG-Git custom version; additional local menu edits on
another computer cannot be reconstructed from a startup log alone.
Some old hooks report `?` or differently formatted versions despite the pinned
package version. EEGLAB also offers catalog QuickLab 0.91 as an update to the
custom hook's 0.1. Do not replace this custom QuickLab using that offer: use
MPG-Git updates to retain the comparison fix. The manifest is the package
version record for this build.

MATLAB Signal Processing and Statistics and Machine Learning toolboxes are
required by workflows such as RELAX. Other selected methods can require more
toolboxes, binaries, or study-specific channel/head models. The installer
cannot supply MATLAB licenses or infer these settings from a startup log.

Official references: [EEGLAB release history](https://eeglab.org/others/EEGLAB_revision_history.html),
[official release ZIPs](https://sccn.ucsd.edu/eeglab/download/daily/),
[extension catalog](https://sccn.ucsd.edu/eeglab/plugin_uploader/plugin_list_all.php).
