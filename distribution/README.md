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

## Install once, then use the desktop shortcut

1. Download **EEGLAB2026-Setup.exe** from the [desktop release](https://github.com/MPG-Git/QuickLab/releases/tag/eeglab-desktop-v1.2.1).
2. Double-click it, then click **Install and open EEGLAB**. MATLAB is detected automatically; choose its `matlab.exe` if detection fails.
3. Wait for the downloads and practice checks. MATLAB windows may open briefly during validation. EEGLAB opens when the checks pass.

After that, double-click **EEGLAB 2026** on the desktop. No commands, GitHub account, or administrator access are needed. An installed, licensed MATLAB is required. The executable is currently unsigned, so Windows may show a publisher notice. If Windows blocks it, contact the maintainer rather than disabling protection.

The installer downloads approximately 1 GB and needs extra disk space for the application, cache and retained versions. It stores the managed installation under `%LOCALAPPDATA%\MPG\EEGLAB`. Existing EEGLAB installations remain in place. Keep recordings in a separate data folder.

The desktop shortcuts are:

- **EEGLAB 2026**: check for a tested update, then open EEGLAB.
- **EEGLAB Practice**: open EEGLAB and run both generated-data examples.
- **EEGLAB Previous Version**: switch back to the previous validated installation. Available after the first update.

### How updates work

At launch, the shortcut checks public MPG-Git/QuickLab releases. A newer stable desktop release offers a **Yes / No** choice: update and open, or use the current version. Declining postpones the offer for a day. Offline or unavailable GitHub checks still open the installed version.

An update is downloaded, checked against GitHub's SHA-256 digest, installed into a new version folder, and tested in MATLAB. Startup registration for all inventoried plugins and both synthetic examples must pass before the active version changes. Failed checks preserve the current installation. Old versions and practice outputs are retained; recordings are never an update target. Running MATLAB sessions continue using their existing installation.

After a rollback, that release is held back so it is not immediately offered again. A later release can still be offered. Third-party plugin updates and GitHub commits are included only when the maintainer pins and tests them in a new desktop release. See [publishing updates](desktop/UPDATING.md).

The launcher uses one EEGLAB root, enables the full menus required by TBT, and selects FieldTrip-lite ahead of Fileio. It does not permanently save the MATLAB path. Once normal workflows work with the new build, the old installation can be archived.

### Help when something goes wrong

Version 1.1.0 asks once whether to send limited technical error reports privately
to the maintainer. Choose **Yes** to enable it or **No** to keep automatic
reporting off. No GitHub or Supabase account is needed. Change this choice later
using **Error reporting settings** in EEGLAB.

The **Get error report** menu saves a readable technical report and opens its
folder so it can be attached to an email. This also works with automatic
reporting off. Neither feature includes recordings, error-message text,
commands, participant names, or personal file paths. Raw MATLAB logs stay local.
Automatic delivery retries when online; GitHub collection normally runs hourly.
Not every MATLAB failure can be captured. See [reporting details](desktop/REPORTING.md).

### Advanced: script-only installation

The original `Install-EEGLAB.ps1 -Destination <new-folder>` remains available for maintainers. It does not install the desktop updater; use the EXE for the no-command workflow.

## Synthetic examples

QuickLab and NeuroLode include small synthetic datasets, reference outputs,
verification scripts and README files under their `examples/synthetic` folders.
Follow those READMEs to reproduce and compare results. Other plugins retain
whatever examples their official packages provide; a synthetic test of every
third-party algorithm has not been supplied or claimed.

Use the **EEGLAB Practice** shortcut or **Practice data** menu without typing. The command-line equivalent is:

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
integration have not been validated. SPM is updated to the official stable
26.10.01 MATLAB distribution, including its Windows binaries. Its NIfTI
read/write and sampling APIs were tested. SPM's native M/EEG interface adds
its own bundled FieldTrip: use that interface in a separate clean MATLAB
session, not inside this EEGLAB session. Full SPM M/EEG workflows are unverified.
QuickLab uses the tested MPG-Git custom version; additional local menu edits on
another computer cannot be reconstructed from a startup log alone.
Desktop 1.2.0 corrects missing version labels using versioned plugin folders
and normalizes EYE-EEG's hook version spelling. Our maintained edition is
registered as **QuickLabMPG 1.0.0**, with the usual **QuickLab** menu, so it is
not mistaken for the historical QuickLab 0.91 catalog plugin.
Fileio's redundant standalone startup function is omitted; its readers and
writers remain installed, using FieldTrip-lite's initializer. FieldTrip's
path warnings remain enabled. The manifest records every pinned package.
The official stable EEGLAB release and extension catalog were checked on
13 November 2026; see [version audit](VERSION_AUDIT.md).

MATLAB Signal Processing and Statistics and Machine Learning toolboxes are
required by workflows such as RELAX. Other selected methods can require more
toolboxes, binaries, or study-specific channel/head models. The installer
cannot supply MATLAB licenses or infer these settings from a startup log.

Official references: [EEGLAB release history](https://eeglab.org/others/EEGLAB_revision_history.html),
[official release ZIPs](https://sccn.ucsd.edu/eeglab/download/daily/),
[extension catalog](https://sccn.ucsd.edu/eeglab/plugin_uploader/plugin_list_all.php).
