# GitHub Maintenance Workflow

This project is intended to be maintained with GitHub so changes stay traceable and easy to review.

## Recommended daily flow

1. Pull the latest code.
2. Create or switch to a working branch for a change.
3. Edit files and test on the target Linux server.
4. Commit with a short action-focused message.
5. Push the branch to GitHub.
6. Open a Pull Request when the change is ready to review.

## Example commands

```bash
git pull
git checkout -b feature/update-entrypoint
git status
git add .
git commit -m "Improve entrypoint startup flow"
git push -u origin feature/update-entrypoint
gh pr create --fill
```

## Commit message style

Use short messages that explain what changed:

- `Add TUN override compose file`
- `Document GitHub maintenance workflow`
- `Add Docker install fallback for Ubuntu`

## Suggested project management usage

- Use Issues for bug reports and feature requests
- Use Pull Requests for every non-trivial change
- Tag versions when the image layout becomes stable
- Keep server-specific secrets and account data out of the repository

## AI collaboration notes

- Keep operational steps documented in `README.md`
- Keep reusable maintenance steps in `docs/`
- Do not commit downloaded vendor packages or runtime data
- When asking AI tools to edit this repo, point them to the exact files to change
