# Hosted deployment, 9 November 2026

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
