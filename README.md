# gnsh-bbq

<div align="center">

[![Validate FiveM resource](https://github.com/Gnesh97/gnsh-bbq/actions/workflows/validate.yml/badge.svg)](https://github.com/Gnesh97/gnsh-bbq/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

### Server-authoritative, slot-based BBQ and grilling system for FiveM

NUI-powered grilling interaction for QBCore and standalone servers with selectable inventory, target, and minigame adapters.

**Version:** `1.0.0` · **License:** [MIT](LICENSE) · **Default framework:** `qbcore` · **Default inventory:** `ox_inventory`

[Installation](#installation) · [Configuration](#configuration) · [Recipes](#recipes) · [Operations](#operations-and-versioning)

</div>

---

## Overview

`gnsh-bbq` manages the full grilling lifecycle from placing a barbecue stand to collecting cooked items into the player's inventory:

1. A grill is placed in the world and registered on the server.
2. Coal is added and the grill is lit.
3. Raw ingredients are placed into available grill slots.
4. Cooking progresses based on current heat; low and high heat modify cooking speed.
5. Players regulate heat using the fanning minigame.
6. Outputs are collected as raw, undercooked, or cooked items depending on cooking progress.

Grill state, heat, slots, interaction leases, and transient actions are held in server memory during runtime. State does not persist across resource restarts, and active grill entities are cleaned up when the resource stops. There are no SQL schemas or database migrations.

## Features

- Grill placement/pickup commands and `mangal` usable-item workflow.
- Coal fueling, ignition, periodic heat decay, and min/max heat clamping.
- Configurable grill slot capacity via `Config.MaxSlots` (default: `10`).
- Recipe-driven cooking with raw, undercooked, cooked, and burnt slot states.
- Optional seasoning modifier (`safeCookBonus` poison-risk reduction and `hungerBonus`).
- Standalone A/D fanning minigame, with optional `qb-skillbar` or `ox_lib` adapters.
- NUI slot/recipe menu and real-time grill heat HUD.
- `qb-target`, `ox_target`, or 3D text fallback interaction.
- Bundled NUI sound engine (`html/sizzling.ogg`) or optional `xsound` integration.
- Server-side validation for entity/model, distance, inventory items, state, cooldowns, and single-user leases.
- Automatic cleanup on player disconnect, lease expiration, and resource stop.

## Supported Integrations

Adapter options in [`config.lua`](config.lua) select which runtime integrations are used. The chosen resource must be running on the server.

| Layer | Supported values | Repository default |
|---|---|---|
| Framework | `qbcore`, `standalone` | `qbcore` |
| Inventory | `qbcore`, `ox_inventory` | `ox_inventory` |
| Target | `qb-target`, `ox_target`, `none` | `ox_target` |
| Notifications | `qbcore`, `ox_lib`, `gta`, `none` | `qbcore` |
| Minigame | `standalone`, `qb-skillbar`, `ox_lib` | `standalone` |
| Sound | `nui`, `xsound` | `nui` |
| Menu | NUI or `qb-menu` / `ox_lib` fallback | NUI |

`standalone` decouples the core workflow from framework calls, though inventory and usable-item behavior still depend on the configured inventory adapter. Validate your chosen combination in staging before deploying to production.

## Requirements

### Resource Dependencies

| Resource | When required |
|---|---|
| `qb-core` | When `Config.Framework = 'qbcore'` (enabled in the default profile). |
| `ox_inventory` | When `Config.Inventory = 'ox_inventory'` (enabled in the default profile). |
| `qb-target` | When `Config.TargetSystem = 'qb-target'`. |
| `ox_target` | When `Config.TargetSystem = 'ox_target'`. |
| `ox_lib` | Required by `ox_inventory` or when selected for notifications, minigame, or fallback menus. |
| `qb-skillbar` | When `Config.MinigameSystem = 'qb-skillbar'`. |
| `qb-menu` | When `Config.UseNuiMenus = false` and using the QB menu fallback. |
| `xsound` | When `Config.SoundEngine = 'xsound'`. |

Because the resource uses no database tables, no SQL import is needed. All NUI assets (HTML, CSS, JS, and `html/sizzling.ogg`) are bundled inside the resource.

### Inventory Items

Register the following items in your inventory system for the default setup:

| Purpose | Items |
|---|---|
| Grill item | `mangal` |
| Coal | `komur`, `coal`, `briket_komur` |
| Ignition | `cakmak`, `lighter` |
| Sausage | `raw_sausage`, `undercooked_sausage`, `cooked_sausage` |
| Chicken | `raw_chicken`, `undercooked_chicken`, `cooked_chicken` |
| Beef | `raw_meat`, `undercooked_meat`, `cooked_meat` |
| Fish | `raw_fish`, `undercooked_fish`, `cooked_fish` |
| Meatball | `raw_meatball`, `undercooked_meatball`, `cooked_meatball` |
| Corn | `sweet_corn`, `undercooked_corn`, `grilled_corn` |
| Optional seasoning | `baharat` |

When using `Config.Inventory = 'qbcore'` alongside `Config.Framework = 'qbcore'`, the resource attempts to register missing QBCore items from `Config.QBItemDefinitions` on startup. For `ox_inventory`, items must be defined in `ox_inventory`'s item definitions and match `Config.Recipes`, `Config.CoalItems`, `Config.IgnitionItems`, and `Config.Seasonings`.

> Note: [`fxmanifest.lua`](fxmanifest.lua) declares `qb-core`, `ox_lib`, `ox_inventory`, and `ox_target` as dependencies for the default production profile. If you switch to a different profile, update the manifest dependencies accordingly.

## Installation

1. Copy the resource into `resources/[standalone]/gnsh-bbq`. If you rename the folder, update the `ensure` line in `server.cfg` to match.
2. Install and start your selected framework, inventory, target, and adapter resources.
3. Register all required items (`mangal`, coal/lighter items, and recipe input/output items) in your inventory system.
4. Review and adjust [`config.lua`](config.lua) for your server.
5. Start dependencies before `gnsh-bbq` in `server.cfg`:

   ```cfg
   ensure qb-core
   ensure ox_lib
   ensure ox_inventory
   ensure ox_target
   ensure gnsh-bbq
   ```

6. Verify the full flow in a staging environment before going live.

## Configuration

All settings live in [`config.lua`](config.lua). Repository defaults are summarized below.

### Framework, Inventory & Interaction

| Setting | Default | Description |
|---|---:|---|
| `Config.Framework` | `qbcore` | `qbcore` or `standalone`. |
| `Config.Inventory` | `ox_inventory` | `qbcore` or `ox_inventory` (independent of framework). |
| `Config.TargetSystem` | `ox_target` | `qb-target`, `ox_target`, or `none`. |
| `Config.EnableNotifications` | `false` | Suppresses script notifications by default. |
| `Config.Enable3DText` | `false` | Enables fallback 3D text interaction when no target resource is used. |
| `Config.InteractDistance` | `2.5` | Client-side interaction distance. |
| `Config.GrillInteractDistance` | `4.0` | Server-authoritative entity distance check. |
| `Config.OnlyOwnerCanRemove` | `false` | Restricts grill pickup to the player who placed it when `true`. |
| `Config.UseNuiMenus` | `true` | Uses NUI for slot and recipe menus. |
| `Config.UseNuiHeatHud` | `true` | Enables the heat HUD overlay. |
| `Config.NuiHudDistance` | `1.3` | Visibility radius for the heat HUD. |
| `Config.NuiMenuDistance` | `4.0` | Auto-close radius for open NUI menus (kept separate from `NuiHudDistance` for sloped terrain). |

### Commands & Timings

| Setting | Default | Description |
|---|---:|---|
| `Config.BuildCommand` | `mangalkur` | Command (`/mangalkur`) to request grill placement. |
| `Config.RemoveCommand` | `mangaltopla` | Command (`/mangaltopla`) to pack up a nearby grill. |
| `Config.AddCoalTime` | `3000` ms | Duration for adding coal. |
| `Config.LightGrillTime` | `5000` ms | Duration for lighting the grill. |
| `Config.PlacementRequestTimeout` | `15000` ms | Handshake timeout for grill placement requests. |
| `Config.GrillUseLeaseMs` | `10000` ms | Single-player interaction lock duration. |
| `Config.GrillUseHeartbeatMs` | `3000` ms | Client lease-renewal interval. |

### Heat & Cooking

| Setting | Default | Description |
|---|---:|---|
| `Config.DefaultHeat` | `50` | Initial heat when lit. |
| `Config.MinHeat` / `Config.MaxHeat` | `0` / `100` | Heat bounds. |
| `Config.HeatDecayInterval` | `10` s | Interval between heat decay ticks. |
| `Config.HeatDecayAmount` | `5` | Heat lost per decay interval. |
| `Config.LowHeatThreshold` | `40` | Threshold below which `LowHeatMultiplier` applies. |
| `Config.HighHeatThreshold` | `80` | Threshold above which `HighHeatMultiplier` applies. |
| `Config.LowHeatMultiplier` | `0.5` | Cooking speed multiplier at low heat. |
| `Config.NormalHeatMultiplier` | `1.0` | Cooking speed multiplier at normal heat. |
| `Config.HighHeatMultiplier` | `1.75` | Cooking speed multiplier at high heat. |
| `Config.BurnThreshold` | `180` | Progress threshold at which the slot burns. |
| `Config.CookingTickMs` | `1000` ms | Server cooking simulation tick interval. |

Fanning defaults: `Config.FanHeatGain = 20`, `Config.FanHeatLossOnFail = 5`, and `Config.FanCooldown = 5000` ms.

Food-poisoning defaults: `OnsetDelay = 5` s, `NauseaDuration = 4` s, `Duration = 20` s, and `TickInterval = 5` s. Poisoning chances (`Config.UndercookedPoisonChance`, `Config.RawPoisonChance`) and `Config.Seasonings` (`safeCookBonus`, `hungerBonus`) adjust outcome safety and QBCore hunger metadata.

### Cooking Outcomes

`cookTime` defines the base duration in seconds at a `1.0x` heat multiplier to reach `100%` cooking progress:

- `cookProgress = 0`: returns the raw item.
- `0 < cookProgress < 100`: returns `undercookedItem`.
- `cookProgress >= 100`: returns `cookedItem`.
- `cookProgress >= BurnThreshold`: slot transitions to `BURNT` and burnt contents are discarded when collected (no burnt item is granted).

## Usage

1. With `mangal` in inventory, use the item or run `/mangalkur` to place the grill.
2. Add coal using the first available item from `Config.CoalItems`.
3. Light the grill with an item from `Config.IgnitionItems`.
4. Add raw ingredients via the target menu or NUI slot/recipe menu (`Config.UseNuiMenus`).
5. Optionally apply a seasoning item from `Config.Seasonings` (such as `baharat`).
6. Fan the grill to manage heat — in the standalone minigame, alternate pressing `A` and `D` within `Config.FanBarTimeLimit` (`6000` ms; `FanBarFillPerPress = 9`, `FanBarDecayPerSecond = 7`).
7. Collect cooked food from the slot menu. Packing up the grill refunds non-burnt slot contents and returns the `mangal` item.

## Recipes

Configured in `Config.Recipes` inside [`config.lua`](config.lua):

| ID | Label | `cookTime` | Raw item | Undercooked item | Cooked item | Hunger |
|---|---|---:|---|---|---|---:|
| `sucuk` | Izgara Sucuk | 6 s | `raw_sausage` | `undercooked_sausage` | `cooked_sausage` | 25 |
| `tavuk` | Tavuk Kanat | 8 s | `raw_chicken` | `undercooked_chicken` | `cooked_chicken` | 35 |
| `et` | Dana Biftek | 12 s | `raw_meat` | `undercooked_meat` | `cooked_meat` | 50 |
| `balik` | Izgara Balık | 10 s | `raw_fish` | `undercooked_fish` | `cooked_fish` | 40 |
| `kofte` | Mangal Köfte | 10 s | `raw_meatball` | `undercooked_meatball` | `cooked_meatball` | 45 |
| `misir` | Közde Mısır | 9 s | `sweet_corn` | `undercooked_corn` | `grilled_corn` | 30 |

### Adding a Custom Recipe

Add a recipe entry to `Config.Recipes` and define the matching raw, undercooked, and cooked items in your inventory system:

```lua
{
    id = 'karides',
    label = 'Izgara Karides',
    cookTime = 7,
    rawItem = 'raw_shrimp',
    undercookedItem = 'undercooked_shrimp',
    cookedItem = 'cooked_shrimp',
    hungerAmount = 35,
    foodProp = `prop_cs_steak`
}
```

## Architecture & Security Boundaries

```text
Target / NUI / command
        ↓
Client request
        ↓
Server validation: entity + model + distance + state + item + lock/cooldown
        ↓
In-memory grill state update
        ↓
Client state synchronization and visual feedback
```

| File | Responsibility |
|---|---|
| `fxmanifest.lua` | FiveM manifest, version, NUI files, and script load order |
| `config.lua` | Framework, inventory, recipe, heat, item, NUI, and effect configuration |
| `client.lua` | Entity placement, target/NUI flow, animations, effects, and client state |
| `server.lua` | Grill state, slots, cooking tick loop, item grants/removals, leases, and checks |
| `bridge.lua` | Server-side framework and inventory adapter abstraction |
| `bridge_client.lua` | Client-side notify, progress bar, and minigame abstraction |
| `html/` | NUI slot menu, heat HUD, fanning minigame, and `sizzling.ogg` |

Note that `Bridge.*`, `ClientBridge.*`, and `mangal:*` network events are internal implementation surfaces rather than public exports.

## Project Structure

```text
gnsh-bbq/
├── fxmanifest.lua
├── config.lua
├── client.lua
├── server.lua
├── bridge_client.lua
├── bridge.lua
├── html/
│   ├── index.html
│   ├── script.js
│   ├── style.css
│   └── sizzling.ogg
├── .github/workflows/validate.yml
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE
```

## Localization

Player-facing strings live in `Config.Lang` inside [`config.lua`](config.lua) (Turkish by default) and can be translated directly by editing those keys.

## Troubleshooting

| Symptom | Check |
|---|---|
| Grill fails to place or is rejected | Verify the `mangal` item, distance to placement spot, model definition, and resource start order. |
| Target options do not appear | Check `Config.TargetSystem`, target resource state, and `Config.InteractDistance` (or set `Config.Enable3DText = true`). |
| NUI menu closes too early | Adjust `Config.NuiMenuDistance` independently of `Config.NuiHudDistance`. |
| Items missing from recipe menu | Verify raw items exist in inventory and item IDs match `Config.Recipes` exactly. |
| Cannot collect cooked item | Confirm the grill is in `LIT` state and cooked/undercooked items are registered in inventory. |
| No grilling audio | Check `Config.EnableSound`, `Config.SoundEngine`, `Config.SoundFile`, and `html/sizzling.ogg` (or `xsound` status). |
| Notifications not shown | `Config.EnableNotifications` is `false` by default; enable it and verify `Config.NotifyStyle`. |
| QBCore bridge not ready | Ensure `qb-core` starts before `gnsh-bbq` and restart `gnsh-bbq` if `qb-core` was restarted. |

## Operations and Versioning

- Resource version in [`fxmanifest.lua`](fxmanifest.lua): `1.0.0`
- Release history: [`CHANGELOG.md`](CHANGELOG.md)
- Contribution and release workflow: [`CONTRIBUTING.md`](CONTRIBUTING.md) (`main` for releases, `dev` for integration)
- CI checks Lua syntax (with FiveM backtick hash normalization), manifest presence, and high-confidence credential patterns via [`.github/workflows/validate.yml`](.github/workflows/validate.yml).

## License

Licensed under the [MIT License](LICENSE).
