# Fix duplicate EEGLAB paths and plugin installations

## Replacing the old installation

To replace an older installation, follow the [EEGLAB 2026.1.0 setup guide](distribution/README.md).
Its installer creates a separate build with the 53-plugin inventory and a
launcher that selects one EEGLAB root. The troubleshooting guidance below is
also useful for maintaining an existing installation.

Use this guide when startup reports more than one EEGLAB installation, repeated
QuickLab/DIPFIT entries, an old NeuroLode version, or errors while adding plugins.
The startup log is an inventory, not a successful test of every plugin.

## 1. Inspect without changing the installation

Download and extract [QuickLab main](https://github.com/MPG-Git/QuickLab/archive/refs/heads/main.zip).
Set MATLAB's current folder to the extracted repository root (the folder with
this guide), then run:

```matlab
report = quicklab_setup_report;
```

This reports MATLAB's version, the active and other visible EEGLAB/QuickLab/
NeuroLode/DIPFIT/ERPsource functions, and plugin entry points in the visible
EEGLAB installations. It also checks plugin folders that are not currently on
the path. It does not execute, install, move, or disable any plugin; it does not
change the MATLAB path or save files. Paths can include your local account name,
so review the output before posting it publicly.

Folder names and startup version labels do not prove which helper is executing.
Use the reported active path and the synthetic example to check the installed fix.

## 2. Keep one EEGLAB installation active

Save your work and start a fresh MATLAB session before changing the setup.
Choose one EEGLAB installation. The automated comparison tests were run with
EEGLAB 2020.0 and 2024.2, not 2026.1.0 or every combination of third-party plugins.
For an installation already using EEGLAB 2024, resolve the conflicts there first.

For a temporary clean-path check, substitute your chosen EEGLAB folder below:

```matlab
previousPath = path;             % retain this if you need to restore the session
restoredefaultpath;              % affects this MATLAB session
cd('C:/path/to/chosen/eeglab');   % folder containing eeglab.m
addpath(pwd);                    % add only the root, not genpath(...)
which eeglab -all
eeglab;
```

Do not save this reset path over an unrelated custom MATLAB setup. For a
permanent correction, use MATLAB's Set Path dialog to remove the unwanted
EEGLAB installation and its subfolders, retaining the chosen root and your
other needed tools. Check any `startup.m` that re-adds the unwanted version.
Let EEGLAB add its own subfolders when it starts.

This follows the [official EEGLAB installation guidance](https://eeglab.org/tutorials/01_Install/Install.html).

## 3. Keep one copy of each plugin

Close EEGLAB before changing its plugin folders. Back up superseded folders
**outside both EEGLAB trees and outside the MATLAB path**. Renaming a folder
to `old_QuickLab` inside `plugins` does not reliably disable it: EEGLAB scans
plugin folders for `eegplugin*.m` entry points.

- **QuickLab:** keep one active installation. For a customized QuickLab GUNN
  menu, replace only `plotDifference.m` with the updated file from
  `QuickLab_11.12.21_NL`. Do not also install the entire second QuickLab folder.
  This preserves the custom menu. For a complete installation of this build,
  copy only `QuickLab_11.12.21_NL` into the chosen EEGLAB `plugins` folder.
- **NeuroLode:** back up the old installed version and copy the `Neurolode1.7`
  folder from [NeuroLode main](https://github.com/MPG-Git/NeuroLode/archive/refs/heads/main.zip)
  into the chosen `plugins` folder. The entry point must be directly inside
  that folder. A startup entry saying folder 1.5/code 1.6 is not this update.
  This build returns `1.7.0`; a folder/code warning about `1.7` versus `1.7.0`
  alone is a naming difference, not proof of a failed startup.
- **DIPFIT:** retain one version, such as the already-installed 5.6, rather
  than loading both 5.5 and 5.6.
- **ERPsource:** `Value must be a handle` is a separate startup failure. If it
  remains after path cleanup, use `which eegplugin_erpsource -all` to locate it.
  Its folder can be temporarily backed up outside `plugins` while testing the
  comparison. Its exact source and MATLAB error stack are needed to diagnose
  that plugin; the QuickLab comparison does not require it.

Keep other needed plugins in the chosen installation and change one thing at
a time. A complete third-party bundle cannot be reconstructed from startup
names alone: several entries have no version, and local customizations are not
identified by the log. The [official plugin manager](https://eeglab.org/others/EEGLAB_Extensions.html)
is the normal route for installing catalogued plugins.

## 4. Check the active comparison and example

After restarting EEGLAB:

```matlab
which eeglab -all
which eegplugin_QuickLab -all
which plotDifference -all
which eegplugin_Neurolode -all
which eegplugin_dipfit -all
```

Each should resolve to the intended installation, with no competing copies.
The QuickLab build in this repository now returns the text version `0.1` to
EEGLAB instead of a numeric value that was displayed as `v?`. Repeated calls
to this build's plugin hook reuse its menu. These changes do not resolve a
second installation that is still shadowing the updated functions.

With the complete QuickLab folder installed, run the included known-answer demo:

```matlab
pluginRoot = fileparts(which('plotDifference'));
addpath(fullfile(pluginRoot,'examples','synthetic'));
run_quicklab_demo;
```

Success prints `PASS`: the synthetic Infinity-minus-Average difference has
mean 2 microvolts and RMS approximately 2.121320344 microvolts on every channel.
See [the example guide](QuickLab_11.12.21_NL/examples/synthetic/README.md).
For a helper-only update, the two `.set` files in the download's example data
folder can be loaded manually and compared using the existing menu.

For real data, load matching Infinity and Average versions of the same recording
and retained epochs, then run `plotDifference(ALLEEG, 'select')`. An installation
check is not validation of the scientific processing applied to those files.

## If startup still fails

Capture the new startup output and the read-only setup report. The short
`Index exceeds array bounds` line does not identify the failing source line.
For a failure caught during plugin startup, MATLAB's `dbstop if caught error`
can expose the stack, but it may stop on unrelated caught exceptions too. At
the relevant debugger stop, use `dbstack('-completenames')`; finish with
`dbquit` and `dbclear if caught error`. Do this in a fresh test session.
