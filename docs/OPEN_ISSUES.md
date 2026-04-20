# Open Issues

This file tracks unresolved work items that should remain visible in the repository even before dedicated GitHub Issues are created.

## High priority

### 1. Extract a stable pure headless `core` mode workflow

Status:
- Incomplete

Evidence:
- The embedded `ScclientCore_amd64` exists and can run as Mihomo
- Login and subscription sync appear to be tied to the GUI
- The expected generated `config.yaml` was not stably accessible after startup attempts

Next step:
- Determine whether the official client writes a usable config only temporarily
- Capture or reconstruct the generated Mihomo configuration after successful startup
- Document a repeatable migration from GUI bootstrap mode to `MODE=core`

## Medium priority

### 2. Improve observability of the official client

Status:
- Incomplete

Problems:
- `app_2026-04-16.log` is not plain text
- `cache.db` is not standard SQLite

Next step:
- Investigate whether logs are compressed, binary encoded, or protobuf-like
- Check whether newer package versions expose clearer diagnostics

### 3. Decide whether unpacked analysis directories should be versioned

Status:
- Deferred

Current decision:
- The repository tracks the build inputs and output bundle
- Runtime logs and generated data stay out of Git
- Unpacked analysis directories from earlier investigation were left outside the repo for now

Next step:
- If future maintenance benefits from preserved reverse-engineering context, add them in a dedicated branch after cleanup
