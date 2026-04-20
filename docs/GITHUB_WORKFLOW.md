# GitHub Maintenance Workflow

This project is intended to be maintained through GitHub so code changes, package updates, and deployment decisions remain traceable.

## Recommended daily flow

1. Pull the latest `main`
2. Create a dedicated branch for the change
3. Update code or documentation
4. Validate the change locally when possible
5. Re-test the build or runtime behavior on the target Linux server
6. Commit with a short action-focused message
7. Push the branch to GitHub
8. Open a Pull Request for any non-trivial change

If the change affects the Docker image, do not skip the remote validation step. The current maintenance baseline assumes real verification on the Linux server before merging.

## Repository prerequisites

Before working with the tracked package archives, install Git LFS:

```bash
git lfs install
```

The repository currently depends on:

- normal Git for source and documentation
- Git LFS for `linux.zip`
- SSH access for pushing to GitHub

## Example branch workflow

```bash
git pull
git checkout -b feature/update-entrypoint
git status
git add .
git commit -m "Improve entrypoint startup flow"
git push -u origin feature/update-entrypoint
gh pr create --fill
```

## Package update workflow

When Speedcat releases a new Linux package, use a dedicated branch and treat it as a build-input change, not just a file replacement.

Recommended flow:

1. Create a branch such as `feature/update-speedcat-package`
2. Replace `linux.zip`
3. Replace the extracted build archive used by `Dockerfile`
4. Recalculate the SHA256 of the extracted archive
5. Update `SCCLIENT_TARBALL_SHA256` in `Dockerfile`
6. Review `README.md` and `docs/` for version-specific behavior changes
7. Rebuild on the Linux server with `docker compose build`
8. Commit and push only after the new checksum passes in the real build

Example SHA256 commands:

Windows PowerShell:

```powershell
Get-FileHash .\scclient_1.33.12_linux_universal_amd64.tar.gz -Algorithm SHA256
```

Linux:

```bash
sha256sum ./scclient_1.33.12_linux_universal_amd64.tar.gz
```

If the archive is replaced but `SCCLIENT_TARBALL_SHA256` is not updated, the Docker build should fail early by design.

## Remote validation workflow

For build or runtime changes, validate on the Linux host before merging.

Typical flow:

```bash
scp Dockerfile entrypoint.sh docker-compose.yml einfash:~/speedcat-docker/
ssh einfash
cd ~/speedcat-docker
docker compose build
docker compose up -d
```

If the change affects optional admin ports or compatibility overlays, test those explicitly as well.

## Commit message style

Use short messages that describe the concrete change:

- `Add package checksum verification`
- `Add UI rate limiting`
- `Tighten Dockerfile runtime contract`
- `Document system proxy dependency`

## Suggested project management usage

- Use Issues for unresolved bugs, follow-up hardening work, and future headless-mode research
- Use Pull Requests for any change that is more than a trivial typo fix
- Tag stable milestones when the build, package version, or deployment contract changes
- Keep secrets, `.env`, and account data out of Git
- Keep package updates and security changes in separate branches when practical

## Documentation discipline

- Put end-user or operator instructions in `README.md`
- Put reusable maintenance knowledge in `docs/`
- Keep `docs/MAINTENANCE_NOTES.md` focused on technical findings and root causes
- Keep `docs/OPEN_ISSUES.md` limited to work that is still unresolved
- Update `docs/SECURITY.md` whenever port exposure, authentication, privileges, or image trust assumptions change

## AI collaboration notes

- Tell AI tools which exact files are in scope
- Ask AI tools to preserve tracked package files and not to revert unrelated user changes
- Require AI tools to validate Docker-impacting changes on the Linux server before calling the work complete
- Do not commit runtime logs, screenshots, caches, or exported account state
