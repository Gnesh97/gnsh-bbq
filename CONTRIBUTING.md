# Contribution and release flow

- `main` is the production branch.
- `dev` is the integration branch.
- Use `feature/<short-name>` for larger changes.
- Keep commits focused and describe behavior changes clearly.
- Run the validation workflow before merging into `main`.
- Update `CHANGELOG.md` and `fxmanifest.lua` for every release.
- Create a version tag only after staging smoke tests pass.
- Do not commit secrets, local server data, or generated build output.
