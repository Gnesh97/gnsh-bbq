# Changelog

## [Unreleased]

- Added Cfx.re Asset Escrow ignore rules for editable configuration and NUI files.

## 1.0.0 - 2026-08-18

- Added the production branch and CI validation workflow.
- Added explicit default-profile dependencies for `qb-core`, `ox_lib`, `ox_inventory` and `ox_target`.
- Fixed premature closing of the open grill NUI menu by separating `Config.NuiMenuDistance` from `Config.NuiHudDistance`, including slope and elevated-placement cases.
- Updated Lua CI validation to normalize FiveM backtick hash literals before running the stock Lua 5.4 parser.
- Fan minigame başlangıcında asset yükleme aralığında karakter hareketi engellendi; minigame sonrası pozisyon geri yükleme akışı korundu.
- Finalized food-poisoning timing values and made failed usable-item registrations retryable instead of silently succeeding.
- `Config.EnableNotifications = false` iken zehirlenme mesajlarının zorla gösterilmesi kaldırıldı.
- Yanmış slot içerikleri inventory item’i üretmeden doğrudan atılır.

## Internal pre-release baseline (1.3.0) - 2026-08-11

- Initial version-controlled production baseline.
