# Mangal Script

## Immersive Grill & Cooking System for FiveM

Mangal Script is a polished, configurable cooking experience for FiveM roleplay
servers. Players can place a physical grill, add fuel, light the fire, cook
multiple recipes in parallel, manage heat with a fan minigame and take food
through raw, undercooked, cooked or burnt outcomes.

It is designed for servers that want a social, tactile food activity instead of
a single instant-use item. The system is framework-flexible, visual, and easy
to place into an existing QBCore or standalone economy.

> **Current version:** <code>1.3.0</code>
>
> **Default profile:** QBCore + ox_inventory + qb-target
> **Primary language:** Turkish UI and notifications, with configurable values
> throughout <code>config.lua</code>.

## Product highlights

| Capability | What players experience |
|---|---|
| Physical grill loop | Place, fuel, ignite, cook, manage heat, collect food and remove the grill. |
| Multi-slot cooking | Up to 10 grill slots with per-slot progress and recipe state. |
| Heat management | Heat decay, high/low heat multipliers, burn thresholds and fan timing gameplay. |
| Recipe outcomes | Raw, undercooked, cooked and burnt results with configurable hunger values. |
| Social interaction | A shared world object with a server-side use lease that prevents conflicting actions. |
| Custom presentation | NUI slot controls, heat HUD, particles, smoke, props, sound and notifications. |
| Integration flexibility | QBCore or standalone framework, ox/qb inventory, ox/qb target and selectable notification/minigame providers. |

## Gameplay loop

~~~text
/mangalkur
    ↓
Place the grill in the world
    ↓
Add coal and ignite
    ↓
Choose a recipe and fill grill slots
    ↓
Watch heat and cooking progress
    ↓
Fan the fire when timing matters
    ↓
Collect the result or risk undercooking/burning it
    ↓
/mangaltopla
~~~

Every step is configurable. Server validation controls grill ownership,
distance, inventory operations, placement state, slot changes and the shared
use lock.

## Feature set

### Complete grill lifecycle

- Place one or more configured grill entities through a command or target flow.
- Add normal coal, coal or briquette coal.
- Ignite with a configured lighter item.
- Display live heat and slot status through the bundled NUI.
- Keep a grill interaction lease so two players cannot mutate the same grill at
  the same time.
- Remove the grill and return eligible contents to the player inventory.
- Prevent removal while active contents still need to be collected, according
  to the configured rules.

### Heat and cooking simulation

The default heat model is intentionally easy to tune:

| Setting | Default | Meaning |
|---|---:|---|
| <code>Config.DefaultHeat</code> | <code>50</code> | Starting heat after ignition. |
| <code>Config.MinHeat</code> / <code>MaxHeat</code> | <code>0 / 100</code> | Heat bounds. |
| <code>Config.LowHeatThreshold</code> | <code>40</code> | Below this, cooking is slower. |
| <code>Config.HighHeatThreshold</code> | <code>80</code> | Above this, cooking is faster but risk increases. |
| <code>Config.LowHeatMultiplier</code> | <code>0.5</code> | Low-heat cooking multiplier. |
| <code>Config.HighHeatMultiplier</code> | <code>1.75</code> | High-heat cooking multiplier. |
| <code>Config.BurnThreshold</code> | <code>180</code> | Burn result threshold. |
| <code>Config.HeatDecayInterval</code> | <code>10 sec</code> | Heat decay interval. |
| <code>Config.HeatDecayAmount</code> | <code>5</code> | Heat removed each decay period. |

Players can fan the fire through the configured minigame. Success adds heat;
failure removes heat and respects a cooldown. This creates a readable risk /
reward loop without forcing a single difficulty profile on every server.

### Recipes and outcomes

The default recipe catalog includes six products:

| Recipe | Cook time | Raw item | Cooked item | Hunger |
|---|---:|---|---|---:|
| Izgara sucuk | 6 sec | <code>raw_sausage</code> | <code>cooked_sausage</code> | 25 |
| Tavuk kanat | 8 sec | <code>raw_chicken</code> | <code>cooked_chicken</code> | 35 |
| Dana biftek | 12 sec | <code>raw_meat</code> | <code>cooked_meat</code> | 50 |
| Izgara balık | 10 sec | <code>raw_fish</code> | <code>cooked_fish</code> | 40 |
| Mangal köfte | 10 sec | <code>raw_meatball</code> | <code>cooked_meatball</code> | 45 |
| Közde mısır | 9 sec | <code>sweet_corn</code> | <code>grilled_corn</code> | 30 |

Every recipe may also produce an undercooked result or the configured
<code>burnt_meat</code> result. Recipe definitions are data-driven, so server
owners can add new raw/cooked item pairs, cook times, hunger values and food
props without rewriting the cooking engine.

### Spice and fuel

- Optional seasoning modifier through <code>baharat</code>.
- Normal coal aliases: <code>komur</code>, <code>coal</code> and
  <code>briket_komur</code>.
- Ignition aliases: <code>cakmak</code> and <code>lighter</code>.
- Briquette coal uses a slower decay multiplier and an ignition bonus by
  default.
- Seasoning can add hunger value and a small safe-cook bonus.

### UI, particles and audio

- NUI slot menu for recipe selection and grill control.
- Independent heat HUD and menu distances.
- Fire and smoke particle effects.
- Cooked-meat and burnt-meat smoke profiles.
- Local sizzling sound through NUI, with optional <code>xsound</code> support.
- QBCore, ox_lib, GTA-native or disabled notification modes.
- Standalone, qb-skillbar or ox_lib fan minigame modes.

The menu-distance fix is intentional: <code>Config.NuiMenuDistance</code> controls
when the open grill menu closes, while <code>Config.NuiHudDistance</code> controls
the heat HUD. A player can therefore keep the HUD behavior tight without
prematurely closing a usable menu.

## Compatibility matrix

| Area | Supported values |
|---|---|
| Framework | <code>qbcore</code>, <code>standalone</code> |
| Inventory | QBCore inventory bridge, <code>ox_inventory</code> |
| Target | <code>qb-target</code>, <code>ox_target</code>, <code>none</code> |
| Notifications | QBCore, <code>ox_lib</code>, GTA native, disabled |
| Minigame | Standalone, <code>qb-skillbar</code>, <code>ox_lib</code> |
| Sound | Bundled NUI sound, <code>xsound</code> |
| UI fallback | 3D interaction text and keybind when target is disabled |

The resource does not require every provider. Set the corresponding
<code>Config.*</code> value to the provider you run, or keep the default
configuration when the automatic bridge is appropriate.

## Requirements

### Minimum

- FiveM server using the <code>cerulean</code> resource manifest.
- A configured framework choice: QBCore or standalone.
- An inventory choice when items are required.
- The item definitions used by your recipes, fuel and ignition flow.

### Optional integrations

- <code>qb-core</code>
- <code>ox_inventory</code>
- <code>qb-target</code> or <code>ox_target</code>
- <code>ox_lib</code>
- <code>qb-skillbar</code>
- <code>xsound</code>

In standalone mode, the core grill flow remains available while framework-owned
inventory or notification behavior is replaced by the configured fallback.

## Installation

1. Copy the resource to your server:

   ~~~text
   resources/[standalone]/mangal_script
   ~~~

2. Register the items used by your recipe, fuel and ignition configuration.
   QBCore item definitions are available in <code>Config.QBItemDefinitions</code>;
   adapt them to your inventory if needed.
3. Start the optional providers before the grill resource.
4. Add the resource to <code>server.cfg</code>:

   ~~~cfg
   ensure mangal_script
   ~~~

5. Open <code>config.lua</code> and choose the framework, inventory, target,
   notification, minigame and sound providers.
6. Confirm that the grill model and local audio asset exist when custom assets
   are configured.
7. Restart the resource and test placement, fuel, ignition, cooking, collection
   and removal with a real player inventory.

## Configuration guide

### Core integration

~~~lua
Config.Framework = 'qbcore'
Config.Inventory = 'ox_inventory'
Config.TargetSystem = 'qb-target'

Config.EnableNotifications = false
Config.NotifyStyle = 'qbcore'
Config.UseNuiMenus = true
Config.UseNuiHeatHud = true
Config.MinigameSystem = 'standalone'
~~~

### Interaction and ownership

~~~lua
Config.InteractDistance = 2.5
Config.GrillInteractDistance = 4.0
Config.OnlyOwnerCanRemove = false
Config.PlacementRequestTimeout = 15000
Config.GrillUseLeaseMs = 10000
Config.GrillUseHeartbeatMs = 3000
~~~

The client provides a smooth interaction experience, but the server performs
the final distance and state checks. The lease/heartbeat pair protects shared
grill state when multiple players interact with the same object.

### Visual and audio controls

~~~lua
Config.GrillModel = 'prop_bbq_5'
Config.UseNuiMenus = true
Config.UseNuiHeatHud = true
Config.EnableMeatSmoke = true
Config.EnableSound = true
Config.SoundEngine = 'nui'
~~~

Replace the model, particle, sound and food-prop values in <code>config.lua</code>
to match the visual identity of your server.

### Commands

~~~text
/mangalkur
/mangaltopla
~~~

Both command names are configurable through <code>Config.BuildCommand</code> and
<code>Config.RemoveCommand</code>. Target integrations expose the same actions
through contextual options.

## Security and state integrity

- Grill operations are mediated by server events and validated against the
  registered grill state.
- Placement uses a short-lived request flow before the entity is accepted.
- Inventory additions/removals are performed through the configured bridge.
- Shared grill mutations are protected by an owner/use lease and heartbeat.
- Distance, empty-slot, inventory-full, duplicate-action and invalid-entity
  cases return controlled user feedback.
- Cleanup handles player drop and resource stop paths.

The system is built for gameplay reliability; administrators should still
protect their framework, inventory and server event surfaces as part of the
overall server security model.

## Customization ideas

- Add recipes for restaurant menus, hunting, fishing or street-food jobs.
- Use seasoning as a job or economy progression item.
- Give briquette coal a premium price and longer cooking sessions.
- Create server events around timed cookouts or food festivals.
- Replace the bundled UI colors, particles and food props to match your brand.
- Add your own item definitions without changing the cooking state machine.

## Troubleshooting

| Symptom | Check |
|---|---|
| Grill does not appear | Confirm <code>Config.GrillModel</code>, model streaming and placement logs. |
| Target options are missing | Confirm <code>Config.TargetSystem</code> and the selected target resource is running. |
| Menu closes too early | Tune <code>Config.NuiMenuDistance</code>; it is independent from <code>Config.NuiHudDistance</code>. |
| Notifications do not show | Check <code>Config.EnableNotifications</code> and <code>Config.NotifyStyle</code>. |
| Food cannot be added | Confirm raw item names, inventory bridge and available recipe slots. |
| Grill will not ignite | Confirm a configured coal item and ignition item are present. |
| Sound is silent | Check <code>Config.SoundEngine</code>, sound file path and provider state. |
| QBCore bridge is unavailable | Start <code>qb-core</code> before this resource and verify the configured resource name. |

## Project documentation

- [CHANGELOG.md](CHANGELOG.md) — release notes and current changes
- [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) — release gate
- [docs/STAGING_TEST_MATRIX.md](docs/STAGING_TEST_MATRIX.md) — staging scenarios
- [docs/ROLLBACK.md](docs/ROLLBACK.md) — rollback procedure
- [docs/DEPLOYMENT_BACKUP.md](docs/DEPLOYMENT_BACKUP.md) — backup guidance

## Ownership

The resource is authored by Gnesh. Review the repository license and the
license terms of any third-party models, sounds, fonts or images before
commercial deployment.
