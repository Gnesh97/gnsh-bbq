# Deployment backup plan

Before a production update, store a timestamped backup outside the live resource directory.

Back up:

- The current BBQ resource directory.
- `server.cfg` and any permission configuration used by the resource.
- Inventory/framework configuration that affects grill items.
- The current version tag and deployment notes.

Example PowerShell outline:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item -Recurse -LiteralPath '<resource-path>' -Destination "<backup-root>\gnsh-bbq-$stamp"
```

Do not place credentials in the backup notes. Verify that the copied directory can be restored before deleting the previous release.
