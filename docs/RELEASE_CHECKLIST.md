# Production release checklist

## Before merge

- [ ] Work is merged from `dev` after review.
- [ ] CI is green for the exact commit being released.
- [ ] `fxmanifest.lua` version and `CHANGELOG.md` agree.
- [ ] No secrets, local server files, or generated output are included.
- [ ] BBQ happy path and invalid-input tests passed on staging.

## Release

- [ ] Create an annotated tag such as `v1.3.0`.
- [ ] Create a GitHub Release from that tag.
- [ ] Archive the exact resource directory used for deployment.
- [ ] Back up `server.cfg`, permissions, and resource configuration.
- [ ] Deploy the tagged resource to staging first.
- [ ] Run the staging matrix in `STAGING_TEST_MATRIX.md`.

## Production

- [ ] Confirm the maintenance window.
- [ ] Stop or restart only the affected resource.
- [ ] Check the server console for startup errors.
- [ ] Run the smoke test and confirm NUI, placement, item, ownership, and cleanup flows.
- [ ] Keep the previous tag and backup available until acceptance is complete.
