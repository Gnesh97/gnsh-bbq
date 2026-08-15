# Staging test matrix

Record the version, date, tester, result, and notes for each row.

| Scenario | Expected result |
|---|---|
| Clean resource start | No startup error; manifest version is visible in logs. |
| Grill placement | Server validates the request, item is consumed once, and state synchronizes. |
| NUI add/pick/light/fan flows | UI closes or refreshes correctly and server owns the outcome. |
| Invalid net ID, recipe, slot, or seasoning | Request is rejected without state or item mutation. |
| Duplicate and rapid requests | Rate limit/lease prevents double execution. |
| Ownership and distance checks | Another player cannot use or remove a protected grill. |
| Player disconnect during use | Lease, pending action, and temporary state are released. |
| Resource restart | Temporary state and entities do not leave stale locks. |
| Two-player concurrent use | Only the authorized lease holder can complete the action. |
| Rollback smoke test | Previous tagged release starts and the main flow works. |
