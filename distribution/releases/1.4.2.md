# Desktop 1.4.2 update trial — 23 November 2026

This release supports the lab's requested real 1.4.1-to-1.4.2 automatic-update
trial. The visible confirmation is **Updates (1.4.2)** at the top of EEGLAB.
No filtering, plotting, other analysis algorithms, plugin pins or synthetic
examples have changed. This release makes no claim to fix the subsequently
withdrawn filtering report.

## Try the update

1. Save your work and close MATLAB.
2. Double-click the existing **EEGLAB 2026** desktop shortcut.
3. When offered **1.4.2**, click **Yes** and leave the updater running.
4. After EEGLAB opens, confirm **Updates (1.4.2)** at the top.
5. Click **Practice data** to run the included examples.

Alternatively, use **Updates (1.4.1) > Check for updates** while EEGLAB is open.
Click **Yes**; after installation completes, save, close MATLAB and reopen the
desktop shortcut. No installer download or MATLAB commands are needed.

## Verification

Passed on Windows PowerShell 5.1 and MATLAB R2023b Update 3:

- 27 discovery/controller/child-process checks and 16 updater contract checks.
- The unchanged installed 1.4.1 updater installed the built 1.4.2 package into
  an isolated managed installation. MATLAB startup, plugin registration and
  comparison, REST/Infinity, ICA and NeuroLode synthetic examples passed.
- Activation retained the previous installation; actual rollback selected
  1.4.1 and held 1.4.2. The old installation's manifest was unchanged.
- Real managed startup with the remote catalog disabled registered all 53
  inventoried plugins plus EEG-BIDS and displayed **Updates (1.4.2)**. Its
  actual update-menu callback launched the active controller without closing
  the session or altering unsaved EEG. GUI checks were programmatic.
- 19 Windows reporting checks and 18 reporting-service/database/identity tests.
- Payload comparison against published 1.4.1 confirms unchanged runtime source
  and plugin manifest, apart from a text file's line endings. Changes are the
  release version, versioned reporting catalog and reporting publication docs.

| Public asset | Bytes | SHA-256 |
| --- | ---: | --- |
| EEGLAB2026-Setup.exe | 3193856 | `f266ebe4c20c5b152712518ada9f0fd58c3ceb95002d7247f8b3680fd894d6ba` |
| EEGLAB2026-Update.zip | 3174268 | `3c88c4d06e34adce7c24bbe64fc5f93649220f4d526232f458a25ad51b6f7c3a` |
| desktop-update.json | 291 | `f75853fe69dc6b740dfcefe0ddc136ec2bebff4b8736688ea4e9b781a7cd71c9` |

## Reporting status and limits

The new catalog retains all previous releases and recognizes 13,187 shipped
MATLAB source files. The private collector catalog is updated. The live
Supabase service still reports 1.4.0; deployment of its newer catalog and live
delivery verification remain pending. Unacknowledged reports remain queued
for retry within the existing 30-day retention period. No successful live
1.4.2 reporting claim is made. Reporting does not block software updates.

These checks do not establish that every third-party workflow works or that
Dr. Gilbert's own computer has updated. The lab's remote trial confirms that.
