# Error reports for users

Dr. Gilbert does not need a Supabase account, a GitHub account, or any hosting
setup. Those services belong to the maintainer. Analysis menus work as before.

**Get error report** in the main EEGLAB menu saves a small text file and opens
its folder. Email that file to Matt. This works offline and with automatic
reporting disabled. If there are no observed errors, the file says so.

When the reporting service is connected, the first launch asks whether to send
technical reports automatically. The default is **No, turn off**. The choice is
remembered across updates. **Error reporting settings** changes it later.
Turning it off removes pending uploads and stops future uploads; reports already
received by the service or GitHub are not recalled. A request already in flight
may complete. Contact the maintainer to remove previously received reports.

Reports contain only a fixed error code, package/MATLAB release, coarse activity
(startup, practice, runtime or update), time, random event identifier, and code
locations from an allowlist of shipped source files. They do not contain raw
exception messages, commands, variable values, EEG, recordings, screenshots,
participant details, personal paths, usernames or hardware identifiers.
Unknown error identifiers become code 0. Unknown source files are omitted.
Hosting/network providers process normal connection metadata, including IP
addresses; the reporting database and GitHub issue do not receive/store an IP
field from the application.

Technical history is stored locally below the managed installation's
`reporting/history` directory. Up to 100 records are retained, with 30-day
pruning when new records arrive. Only reports created after consent go into the
upload queue. The background sender retries approximately once a minute while
the launched MATLAB session runs, and on the next launch. Each attempt is
bounded and does not block an analysis. A service acknowledgment means the
report is in its private queue; GitHub delivery follows separately.

The maintainer's private GitHub repository collects queued reports on an hourly
schedule (GitHub may delay scheduled runs). Repeated equivalent failures update
one issue and its observation count. Service records are pruned after 90 days
when new reports arrive. GitHub issues remain until the maintainer removes them.
The service limits intake to 250 new events per day; queued client reports retry
later if that limit is reached. No GitHub credential is shipped to a user or to
Supabase; delivery uses GitHub Actions' short-lived repository token and a signed workflow
identity for the reporting service. No shared relay secret is needed.

## Coverage

Startup and practice failures are caught explicitly. A MATLAB timer samples
MATLAB's legacy last-error state when MATLAB can service its event queue. The
newer `MException.last` API cannot be used from a timer. The monitor does not
reset MATLAB's error state. A reported error may have been handled internally by
a plugin; an issue does not by itself prove an analysis failed. Multiple errors
between polls, identical repeated errors, overwritten error state, native
crashes, hangs and errors before diagnostics starts may not be captured. Counts
are observations, not an exhaustive error count. Existing full session logs stay
local and are never uploaded or copied by Get error report.

Automatic reporting remains unavailable when the release's `reporting.json`
has an empty endpoint. Local history and Get error report still work. A hosted
end-to-end synthetic delivery test is required before publishing an installer
that claims automatic GitHub delivery is connected.
