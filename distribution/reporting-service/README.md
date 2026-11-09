# Private EEGLAB error reporting

The public installer has no GitHub credential and needs no user account. Only
the maintainer connects hosting. A Supabase Edge Function validates a strict
technical schema and stores reports in tables protected by row-level security.
An hourly workflow in a **private** support repository retrieves report groups
with a GitHub-signed, short-lived OIDC identity and creates/updates GitHub issues using its
short-lived `GITHUB_TOKEN` with `issues: write`. The workflow refuses a public
repository. GitHub credentials never leave GitHub.

## Deployment

1. Connect a maintainer-owned Supabase project (prefer a dedicated project).
   Apply `migration.sql`. Anonymous and authenticated Supabase roles cannot
   read the tables or execute the RPCs. Only the function service role can.
2. Deploy an Edge Function named `eeglab-reports` with `index.ts`, `service.mjs`
   and `github-identity.mjs`, plus `diagnostic-sources.json`. Set `verify_jwt = false`: the report endpoint
   intentionally accepts account-free, allowlisted technical reports. Private
   `claim` and `ack` endpoints accept only a signed identity from the exact private collector workflow on main, owned by GitHub account ID 214007000. There is no
   client-provided text field and a transactional global limit of 250 events/day.
   This limits report intake, not arbitrary HTTP traffic or provider costs;
   configure the provider's spending/traffic controls for the hosting account.
3. The function requires only Supabase's built-in service-role environment. No
   shared secret, GitHub password or personal access token is configured. Its
   authorizer pins GitHub's issuer/JWKS, audience, owner ID, private repository,
   main branch, workflow path and allowed trigger types; tokens expire quickly.
4. In the private support repository, copy `collect-reports.mjs`, `service.mjs`,
   `github-identity.mjs` and `diagnostic-sources.json` to its root. Copy
   `collect-reports.yml` to `.github/workflows/collect-reports.yml`. The public
   endpoint is pinned in that workflow. Set repository variable
   `REPORTING_READY=true` only after hosted testing. Watch issues for notifications.
5. Test with a synthetic event: POST `/report`, dispatch the collector workflow,
   verify a private issue, post a second equivalent event and confirm that the
   same issue gets count 2. Exercise unauthenticated claim refusal and RLS.
6. Set the public desktop `reporting.json` endpoint to that base URL plus
   `/report`. Build and test a new desktop release with the actual endpoint.
   Test consent off, consent on, export, offline retry, and withdrawal. Only
   then publish the release. Never replace an already published asset in place.

The hosted service has no GitHub token. Supabase supplies its internal service
role credential to the function; that key is never returned to a client. The
collector uses GitHub OIDC instead of a shared secret. The service validates
its signature and exact workflow identity before retrieving or acknowledging reports.

## Tests

`npm ci && npm test` runs handler/privacy and collector tests, signed-identity rejection tests, plus the actual
PostgreSQL migration in PGlite. PGlite validates SQL/permissions/transaction
behavior locally; live Supabase RLS, gateway configuration and GitHub Actions
must also be checked after deployment. Client checks are in
`../desktop/tests/Test-Reporting.ps1` and `test_diagnostics.m`.

`build_catalog.py <validated-installation-root>` catalogs only shipped MATLAB
code below the EEGLAB and dependency roots plus explicit launcher helpers. It
checks the manifest before scanning and never scans user data. Source IDs are
128-bit truncated SHA-256 hashes of normalized package-relative file names.
Only known IDs are accepted; private issues display the catalog's code paths.

The collector uses a delivery lease and searches for its fingerprint marker
before creating an issue, recovering from most interrupted create/ack attempts.
GitHub search is eventually consistent, so an exceptional retry can still
produce a duplicate issue. Delivery failures remain queued for the next run.
No real recordings or user logs should be used for deployment tests.

Preserve the previous catalog entries when building a new release so queued
reports from older installed versions can still be validated and delivered.
