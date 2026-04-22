# Open Issues

This file tracks work that is still unresolved after the current packaging, hardening, and validation milestone.

## High priority

### 1. Extract a stable pure headless `MODE=core` workflow

Status:

- Open

Why it still matters:

- the current project is functional, but it still depends on GUI mode for the fully validated bootstrap path
- a pure headless mode would reduce the runtime surface, simplify operations, and improve security

What is already known:

- `ScclientCore_amd64` exists and runs as the embedded proxy core
- the official GUI is still the only validated path for login and subscription synchronization
- the generated Mihomo-compatible configuration was not yet captured in a repeatable, durable way

Next steps:

- determine when and where the official client writes the effective config
- test whether the config is temporary, encrypted, or rewritten during startup
- document a repeatable path from GUI bootstrap to long-lived `MODE=core`

### 2. Re-validate assumptions when Speedcat releases a newer Linux package

Status:

- Open

Why it still matters:

- the project is now pinned to a specific package version and checksum
- future vendor updates may change the embedded core, GUI behavior, runtime dependencies, or connection-state logic

Next steps:

- replace the tracked package files on a dedicated branch
- update the SHA256 in `Dockerfile`
- rerun the full remote validation checklist
- confirm that `libglib2.0-bin`, `dconf-cli`, `NET_ADMIN`, and `/dev/net/tun` are still sufficient

## Medium priority

### 3. Improve observability of the official client

Status:

- Open

What is blocking visibility:

- `app_2026-04-16.log` was not plain text during earlier investigation
- `cache.db` did not behave like a normal SQLite database
- the official binary remains difficult to introspect compared with a standard open-source client

Next steps:

- determine whether logs are compressed, binary-encoded, or protobuf-like
- check whether future vendor releases expose clearer diagnostics
- identify the minimal runtime signals needed for automated health checks

### 4. Stabilize headless GUI automation for secondary validation containers

Status:

- Open

Why it still matters:

- the primary service path has already been validated end-to-end
- a second container launched from the pulled Docker Hub image can already expose its authenticated UI successfully
- but deterministic headless automation of the in-app `连接` click is still flaky, which makes unattended post-pull proxy verification weaker than it should be

What is already known:

- the pulled-image test container can start noVNC and serve the UI on alternate ports
- the focused app window can be detected with `xdotool`
- simple coordinate-based click injection did not reliably flip the app from `未连接` to `已连接`

Next steps:

- inspect whether Electron or the desktop stack is swallowing synthetic pointer input
- test whether keyboard shortcuts or accessibility actions can trigger the same connection flow more reliably
- decide whether post-pull validation should remain manual at the GUI layer or move to a lower-level signal

### 5. Automate image publishing for the prebuilt-image workflow

Status:

- Open

Why it still matters:

- the repository now prefers `docker pull` for operators
- that model is strongest when image publication is reproducible and routine
- manual publishing steps are easy to forget during package refreshes

Next steps:

- keep Docker Hub as the current canonical operator-facing registry unless requirements change
- add a documented tagging policy
- automate build-and-push steps in CI or a controlled maintainer workflow

### 6. Decide whether reverse-engineering artifacts should be curated in-repo

Status:

- Deferred

Current decision:

- the repository tracks only the build inputs and the maintained deployment code
- runtime logs, caches, and account-state data remain out of Git
- earlier ad hoc unpacked analysis artifacts were intentionally not added

Next steps:

- only add cleaned reverse-engineering notes or artifacts if they provide lasting maintenance value
- if added later, isolate them in a dedicated branch or clearly labeled documentation area
