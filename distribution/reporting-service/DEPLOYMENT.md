# Hosted deployment

## Detailed update reports, 13 November 2026

The live function now imports QuickLab commit
`423e614570974b29d112a08087e29610fd1f9586`, supporting desktop 1.2.1 and
schema 2 structured update details. Schema 1 reports and the 1.1.0/1.2.0
catalogs remain supported. Private collector commit
`ae30b8ffd437efb56208dc62689894d198610c61` passed live run `43519414884`.
The installed Windows sender also passed real intake/private delivery as
synthetic issue #12. No database migration, credential, access or consent
change was needed. Raw log and exception-message text remains excluded.

## Update, 13 November 2026

Desktop 1.2.0 is supported by the function pinned to QuickLab commit
`a066850ee77f18e6168d4b050ed6df7e9ae45a2f`. Its catalog retains 1.1.0.
Private collector commit `bb87ecaeb3dddeb87edf36f48abdf90fd88ead34` and
live workflow run `43515925434` passed, including intake, privacy rejection,
OIDC authorization, deduplication, and grouped private issue delivery.
Authentication, consent, database permissions and retention are unchanged.
See [1.2.0 verification](../releases/1.2.0.md) for the exact tested assets.

## Initial deployment, 9 November 2026

The dedicated EEGLAB Support Supabase project serves
`https://xuhumtlubgkqfcfrrwiv.supabase.co/functions/v1/eeglab-reports`.
The function uses imports pinned to QuickLab commit
`4cffd020a5e55a010a4dbe51d37875fff6a26095`, including its release 1.1.0 catalog.
The migration was applied in a transaction. Live SQL verified RLS on all three
tables, no anonymous/authenticated table reads, and service-role-only claim
execution. Legacy Supabase JWT verification is off because the private routes
verify GitHub OIDC; the public report route deliberately requires no account.

The private MPG-Git/EEGLAB-Support repository runs the collector hourly with
`REPORTING_READY=true`. It requires no maintainer personal access token or
shared relay secret. The manual live-test input exercises the actual endpoint
and GitHub issues. The 9 November run 42716686447 passed at support commit
c63c4b9: valid intake, rejection of free text and unauthenticated claims,
signed workflow authentication, retry deduplication, and grouping to count 2.
Its synthetic issue was marked and closed. No real recordings or logs were used.

Desktop 1.1.0's final payload was installed in a fresh directory with real
MATLAB R2023b Update 3. All 53 registrations and both synthetic examples passed.
Its installed MATLAB helper generated a synthetic report, omitted the private
sentinel, exported it, and queued it with test consent. The actual Windows
PowerShell 5.1 sender received acceptance from Supabase, removed the queued
copy, and retained local history. PowerShell 5.1 is the launcher's pinned runtime.

Artifact checksums:

- EEGLAB2026-Setup.exe SHA-256:
  `B0320E279BC4AE6AB3142C3758B7ABCAFA1F94E3108E97246D51BB9BB7BAEA52`

For maintenance, update and test the source catalog, function and private
collector together before publishing a new desktop package. Keep older
catalogs so queued reports from previous versions remain deliverable.
Disable the repository variable to pause collection; this does not disable
intake or withdraw reports already delivered. User consent controls client
uploads. See the user-facing reporting document for retention and coverage.
