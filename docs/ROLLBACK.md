# Rollback procedure

Use this procedure when a release causes errors, exploit symptoms, broken NUI, or unexpected item/entity behavior.

1. Stop the affected resource and record the current tag and console error.
2. Restore the previous known-good resource archive or checkout.
3. Restore the matching configuration and permissions backup.
4. Restart the resource and verify that existing grills are cleaned up or restored safely.
5. Run the staging smoke test before reopening the production flow.
6. Record the incident and keep the broken release unavailable until fixed on `dev`.

This resource currently has no database migration. If persistence is added later, the release must include a tested migration and a database backup before deployment.
