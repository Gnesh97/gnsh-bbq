-- ====================================================
-- SERVER.LUA - Mangal Script (Yakıt, Tutuşturma, Slot & Izgara Kapasite Yönetimi)
--
-- Framework/envanter erisimi Bridge.* uzerinden yapilir (bkz. bridge.lua).
-- Baska bir core/inventory'e gecmek icin SADECE bridge.lua degisir.
-- ====================================================

local GrillStates = {}   -- Key: netId (number), Value: 'EMPTY' | 'HAS_COAL' | 'LIT'
local GrillHeat = {}     -- Key: netId (number), Value: heat level (10 to 100)
local GrillSlots = {}    -- Key: netId (number), Value: Array of slots [1..MaxSlots]
local GrillOwners = {}   -- Key: netId (number), Value: persistent player identifier
local GrillCoalType = {} -- Key: netId (number), Value: kömür item adi (Config.CoalTypes anahtari)
local FanCooldowns = {}  -- Key: source, Value: { [netId] = timestamp (ms) }
local PendingPlacements = {}
local PendingActions = {}
local EventCooldowns = {}
local GrillUseLocks = {}    -- netId -> { source = player source, expiresAt = ms }
local PlayerGrillLocks = {} -- source -> netId
local AllowedGrillModels = {}
local UsableItemsRegistered = false
local PoisonedPlayers = {}

local Notify = Bridge.Notify

print("^2[mangal_script]^7 Sunucu tarafi baslatildi! Izgara Kapasitesi ve Slot Yönetimi aktif.")

-- ----------------------------------------------------
-- YARDIMCI FONKSİYONLAR & SLOT İLKLEME
-- ----------------------------------------------------
local function NewEmptySlot()
    return {
        isOccupied = false,
        item = nil,
        status = 'RAW',
        cookProgress = 0,
        seasoning = nil,
        isBusy = false
    }
end

local function InitializeGrillSlots(netId)
    local netIdNum = tonumber(netId)
    if not netIdNum or netIdNum == 0 then return end
    GrillSlots[netIdNum] = {}
    local maxSlots = Config.MaxSlots or 6
    for i = 1, maxSlots do
        GrillSlots[netIdNum][i] = NewEmptySlot()
    end
end

local function NormalizeNetId(netId)
    local netIdNum = tonumber(netId)
    if not netIdNum or netIdNum ~= netIdNum or netIdNum <= 0 then return nil end
    return math.floor(netIdNum)
end

local function AddAllowedModel(model)
    local modelHash = tonumber(model)
    if modelHash then AllowedGrillModels[modelHash] = true end
end

AddAllowedModel(Config.GrillModel)
AddAllowedModel(GetHashKey('prop_bbq_5'))
AddAllowedModel(GetHashKey('prop_bbq_02'))

-- cookProgress artik metadata olarak tutulmuyor (tam stackleme icin) --
-- zehirlenme ihtimali sadece item adina (rawItem/undercookedItem/
-- cookedItem) gore sabit bir yuzdeden geliyor.
local function GetPoisonChance(item, recipe)
    if not item or not recipe then return 0 end

    if item.name == recipe.cookedItem then
        return 0
    end

    if item.name == recipe.rawItem then
        return tonumber(Config.RawPoisonChance) or 95
    end

    return tonumber(Config.UndercookedPoisonChance) or 50
end

local function TriggerFoodPoisoning(source)
    if PoisonedPlayers[source] then return end

    PoisonedPlayers[source] = true

    local onsetDelay = tonumber(Config.PoisonSettings.OnsetDelay) or 3
    local duration = tonumber(Config.PoisonSettings.Duration) or 20

    SetTimeout(onsetDelay * 1000, function()
        if not PoisonedPlayers[source] then return end
        TriggerClientEvent('mangal:client:getPoisoned', source, {
            healthLoss = tonumber(Config.PoisonSettings.HealthLoss) or 15,
            duration = duration,
            applyScreenEffect = Config.PoisonSettings.ApplyScreenEffect == true,
            tickInterval = tonumber(Config.PoisonSettings.TickInterval) or 5,
            nauseaDuration = tonumber(Config.PoisonSettings.NauseaDuration) or 2
        })
    end)

    SetTimeout((onsetDelay + duration) * 1000, function()
        PoisonedPlayers[source] = nil
    end)
end

local function CanUseEvent(source, key, interval)
    local now = GetGameTimer()
    EventCooldowns[source] = EventCooldowns[source] or {}
    if (EventCooldowns[source][key] or 0) > now then return false end
    EventCooldowns[source][key] = now + interval
    return true
end

local function GetGrillEntity(netId, requireRegistered)
    local netIdNum = NormalizeNetId(netId)
    if not netIdNum then return nil, nil end
    if requireRegistered and GrillStates[netIdNum] == nil then return nil, nil end

    local entity = NetworkGetEntityFromNetworkId(netIdNum)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil, nil end
    if GetEntityType(entity) ~= 3 then return nil, nil end
    if not AllowedGrillModels[GetEntityModel(entity)] then return nil, nil end
    return netIdNum, entity
end

local function IsPlayerNearEntity(source, entity, maxDist)
    local ped = GetPlayerPed(source)
    if not DoesEntityExist(ped) then return false end
    local pedCoords = GetEntityCoords(ped)
    local entityCoords = GetEntityCoords(entity)
    return #(pedCoords - entityCoords) <= (maxDist or Config.GrillInteractDistance or 4.0)
end

local function ValidateRegisteredGrill(source, netId, maxDist)
    local netIdNum, entity = GetGrillEntity(netId, true)
    if not netIdNum or not IsPlayerNearEntity(source, entity, maxDist) then return nil, nil end
    return netIdNum, entity
end

local function ReleaseGrillUse(src, netId, notifyEvent)
    local netIdNum = NormalizeNetId(netId)
    if not netIdNum then return end

    local lock = GrillUseLocks[netIdNum]
    if not lock or (src ~= nil and lock.source ~= src) then return end

    local owner = lock.source
    GrillUseLocks[netIdNum] = nil
    if PlayerGrillLocks[owner] == netIdNum then
        PlayerGrillLocks[owner] = nil
    end
    if notifyEvent and owner then
        TriggerClientEvent(notifyEvent, owner, netIdNum)
    end
end

local function AcquireGrillUse(src, netId)
    local netIdNum = NormalizeNetId(netId)
    if not netIdNum then return nil end

    local now = GetGameTimer()
    local lock = GrillUseLocks[netIdNum]
    if lock and lock.expiresAt <= now then
        ReleaseGrillUse(nil, netIdNum, 'mangal:client:grillUseLost')
        lock = nil
    end
    if lock and lock.source ~= src then return nil end

    local previousNetId = PlayerGrillLocks[src]
    if previousNetId and previousNetId ~= netIdNum then
        ReleaseGrillUse(src, previousNetId)
    end

    GrillUseLocks[netIdNum] = {
        source = src,
        expiresAt = now + (Config.GrillUseLeaseMs or 10000)
    }
    PlayerGrillLocks[src] = netIdNum
    return netIdNum
end

local function HasGrillUse(src, netId, notifyBusy)
    local netIdNum = NormalizeNetId(netId)
    local lock = netIdNum and GrillUseLocks[netIdNum]
    local now = GetGameTimer()
    if not lock or lock.expiresAt <= now then
        if lock then ReleaseGrillUse(nil, netIdNum, 'mangal:client:grillUseLost') end
        return false
    end

    if lock.source ~= src then
        if notifyBusy then Notify(src, Config.Lang['grill_in_use'], 'error') end
        return false
    end

    lock.expiresAt = now + (Config.GrillUseLeaseMs or 10000)
    return true
end

local function EnsureGrillUse(src, netId, notifyBusy)
    if HasGrillUse(src, netId, notifyBusy) then return true end

    local netIdNum = NormalizeNetId(netId)
    if not netIdNum or GrillUseLocks[netIdNum] then return false end
    return AcquireGrillUse(src, netIdNum) ~= nil
end

RegisterNetEvent('mangal:server:acquireGrillUse')
AddEventHandler('mangal:server:acquireGrillUse', function(requestId, netId)
    local src = source
    local netIdNum = ValidateRegisteredGrill(src, netId, Config.GrillInteractDistance or 4.0)
    if not netIdNum then
        TriggerClientEvent('mangal:client:grillUseResult', src, requestId, netId, false)
        return
    end

    local acquired = AcquireGrillUse(src, netIdNum)
    if not acquired then
        Notify(src, Config.Lang['grill_in_use'], 'error')
        TriggerClientEvent('mangal:client:grillUseResult', src, requestId, netIdNum, false)
        return
    end

    TriggerClientEvent('mangal:client:grillUseResult', src, requestId, netIdNum, true)
end)

RegisterNetEvent('mangal:server:heartbeatGrillUse')
AddEventHandler('mangal:server:heartbeatGrillUse', function(netId)
    HasGrillUse(source, netId, false)
end)

RegisterNetEvent('mangal:server:releaseGrillUse')
AddEventHandler('mangal:server:releaseGrillUse', function(netId)
    ReleaseGrillUse(source, netId)
end)

CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        local expired = {}

        for netId, lock in pairs(GrillUseLocks) do
            if lock.expiresAt <= now then
                expired[#expired + 1] = { netId = netId, source = lock.source }
            end
        end

        for _, entry in ipairs(expired) do
            local lock = GrillUseLocks[entry.netId]
            if lock and lock.source == entry.source then
                ReleaseGrillUse(nil, entry.netId, 'mangal:client:grillUseLost')
            end
        end
    end
end)

local function GetRecipeById(recipeId)
    for _, recipe in ipairs(Config.Recipes) do
        if recipe.id == recipeId then
            return recipe
        end
    end
    return nil
end

local function GetSlotRewardItem(slot)
    if not slot or not slot.isOccupied then return nil end

    local recipe = GetRecipeById(slot.item)
    if not recipe then return nil end

    if slot.status == 'BURNT' then
        return nil
    end

    local cookProgress = tonumber(slot.cookProgress) or 0
    if cookProgress >= 100 or slot.status == 'COOKED' then
        return recipe.cookedItem
    elseif cookProgress > 0 then
        return recipe.undercookedItem or recipe.rawItem
    end

    return recipe.rawItem
end

-- Envanterde tam stackleme calissin diye hicbir pisme-yuzdesi/tier
-- metadatasi tutulmuyor (surekli degisen deger her pickup'ta farkli
-- oldugundan ox_inventory farkli stack aciyordu). Zehirlenme riski artik
-- pickup anindaki pisme derecesine degil, sadece item turune (cig/az
-- pismis/pismis) bagli -- bkz. GetPoisonChance. Baharatli etler ayri
-- bir gorunum/stack alsin diye sabit bir metadata (seasoning + label)
-- tasir.
local function BuildFoodInfo(recipe, slot, targetItem)
    local info = {}

    if slot.seasoning and Config.Seasonings[slot.seasoning] then
        info.seasoning = slot.seasoning
        info.label = string.format('Baharatli %s', recipe.label or targetItem)
    end

    return info
end

local function GetGrillMeatRefunds(netId)
    local refunds = {}
    local meatCount = 0
    local burntCount = 0

    for _, slot in ipairs(GrillSlots[netId] or {}) do
        if slot.isOccupied then
            if slot.status == 'BURNT' then
                burntCount = burntCount + 1
            else
                local itemName = GetSlotRewardItem(slot)
                if not itemName then return nil, 0, 0 end

                local recipe = GetRecipeById(slot.item)
                refunds[#refunds + 1] = {
                    itemName = itemName,
                    info = recipe and BuildFoodInfo(recipe, slot, itemName) or {}
                }
                meatCount = meatCount + 1
            end
        end
    end

    return refunds, meatCount, burntCount
end

local function GiveGrillAndContents(source, meatRefunds)
    local addedItems = {}

    local function RollbackAddedItems()
        for index = #addedItems, 1, -1 do
            local entry = addedItems[index]
            if not Bridge.RemoveItem(source, entry.itemName, entry.amount) then
                print(('^1[mangal_script]^7 KRITIK: %s x%d iade geri alma basarisiz (source: %d).')
                    :format(entry.itemName, entry.amount, source))
            end
        end
    end

    for _, refund in ipairs(meatRefunds) do
        if not Bridge.AddItem(source, refund.itemName, 1, refund.info) then
            RollbackAddedItems()
            return false
        end
        addedItems[#addedItems + 1] = { itemName = refund.itemName, amount = 1 }
    end

    if not Bridge.AddItem(source, 'mangal', 1) then
        RollbackAddedItems()
        return false
    end

    return true
end

local function ClearGrillData(netId, syncClients)
    ReleaseGrillUse(nil, netId, 'mangal:client:grillUseLost')
    GrillStates[netId] = nil
    GrillHeat[netId] = nil
    GrillSlots[netId] = nil
    GrillOwners[netId] = nil
    GrillCoalType[netId] = nil

    if syncClients then
        TriggerClientEvent('mangal:client:syncGrillState', -1, netId, nil)
        TriggerClientEvent('mangal:client:syncGrillSlots', -1, netId, nil)
    end
end

local function BeginAction(source, action, netId, duration)
    local now = GetGameTimer()
    local key = action .. ':' .. netId
    PendingActions[source] = PendingActions[source] or {}
    local current = PendingActions[source][key]
    if current and current.expiresAt > now then return false end

    PendingActions[source][key] = {
        earliestAt = now + math.max(0, duration - 250),
        expiresAt = now + duration + 10000
    }
    return true
end

local function CompleteAction(source, action, netId)
    local actions = PendingActions[source]
    local key = action .. ':' .. netId
    local pending = actions and actions[key]
    if not pending then return false end
    actions[key] = nil

    local now = GetGameTimer()
    return now >= pending.earliestAt and now <= pending.expiresAt
end

local function CancelAction(source, action, netId)
    local actions = PendingActions[source]
    if actions then actions[action .. ':' .. netId] = nil end
end

local function GetHeatMultiplier(heat)
    if heat >= (Config.HighHeatThreshold or 80) then
        return Config.HighHeatMultiplier or 1.75
    elseif heat < (Config.LowHeatThreshold or 40) then
        return Config.LowHeatMultiplier or 0.5
    end
    return Config.NormalHeatMultiplier or 1.0
end

local function GetCoalDecayMultiplier(netId)
    local coalItem = GrillCoalType[netId]
    local coalData = coalItem and Config.CoalTypes and Config.CoalTypes[coalItem]
    return (coalData and tonumber(coalData.decayMultiplier)) or 1.0
end

local function UpdateLitGrillHeat(netId, heat)
    local newHeat = math.max(0, math.min(Config.MaxHeat or 100, tonumber(heat) or 0))
    GrillHeat[netId] = newHeat
    TriggerClientEvent('mangal:client:syncGrillHeat', -1, netId, newHeat)

    if newHeat <= 0 and GrillStates[netId] == 'LIT' then
        GrillStates[netId] = 'HAS_COAL'
        TriggerClientEvent('mangal:client:syncGrillState', -1, netId, 'HAS_COAL')
        TriggerClientEvent('mangal:client:grillExtinguished', -1, netId)
    end

    return newHeat
end

-- ----------------------------------------------------
-- DÖNGÜLER: ISI DECAY VE ET PİŞME SÜRECİ (COOKING TICK)
-- ----------------------------------------------------
CreateThread(function()
    local interval = (Config.HeatDecayInterval or 10) * 1000
    while true do
        Wait(interval)
        for netId, state in pairs(GrillStates) do
            if state == 'LIT' then
                local currentHeat = GrillHeat[netId] or Config.DefaultHeat or 50
                local decayAmount = (Config.HeatDecayAmount or 5) * GetCoalDecayMultiplier(netId)
                local newHeat = math.max(Config.MinHeat or 0, currentHeat - decayAmount)
                if newHeat ~= currentHeat or newHeat <= 0 then
                    UpdateLitGrillHeat(netId, newHeat)
                end
            end
        end
    end
end)

-- Sunucu tarafı et pişirme ve yanma döngüsü.
CreateThread(function()
    local tickMs = math.max(250, Config.CookingTickMs or 1000)
    local tickSeconds = tickMs / 1000.0

    while true do
        Wait(tickMs)
        for netId, state in pairs(GrillStates) do
            if state == 'LIT' and GrillSlots[netId] then
                local heat = GrillHeat[netId] or Config.DefaultHeat or 50
                local heatMultiplier = GetHeatMultiplier(heat)
                local burnThreshold = Config.BurnThreshold or 180
                local hasChanged = false
                for _, slot in ipairs(GrillSlots[netId]) do
                    if slot.isOccupied then
                        local recipe = GetRecipeById(slot.item)
                        local cookTime = math.max(1, recipe and recipe.cookTime or 10)
                        local progressGain = (100.0 / cookTime) * tickSeconds * heatMultiplier

                        if slot.cookProgress < burnThreshold then
                            slot.cookProgress = math.min(burnThreshold, slot.cookProgress + progressGain)
                            hasChanged = true
                        end

                        if slot.cookProgress >= 100 and slot.status == 'RAW' then
                            slot.status = 'COOKED'
                            hasChanged = true
                        elseif slot.cookProgress >= burnThreshold and slot.status == 'COOKED' then
                            slot.status = 'BURNT'
                            hasChanged = true
                        end
                    end
                end

                if hasChanged then
                    TriggerClientEvent('mangal:client:syncGrillSlots', -1, netId, GrillSlots[netId])
                end
            end
        end
    end
end)

-- ----------------------------------------------------
-- STATE VE SLOT SENKRONİZASYONU
-- ----------------------------------------------------
RegisterNetEvent('mangal:server:requestAllStates')
AddEventHandler('mangal:server:requestAllStates', function()
    local src = source
    if not CanUseEvent(src, 'requestAllStates', 3000) then return end

    local playerKey = Bridge.GetIdentifier(src)
    local ownedGrills = {}
    for netId, ownerKey in pairs(GrillOwners) do
        if ownerKey == playerKey then ownedGrills[netId] = true end
    end

    TriggerClientEvent('mangal:client:syncAllGrillStates', src, GrillStates, GrillHeat, GrillSlots, ownedGrills)
end)

-- ----------------------------------------------------
-- QB-CORE USABLE ITEMS
-- ----------------------------------------------------
local function BeginGrillPlacement(source)
    local now = GetGameTimer()
    if (PendingPlacements[source] or 0) > now then
        Notify(source, Config.Lang['action_in_progress'], 'error')
        return
    end
    if not CanUseEvent(source, 'requestPlaceGrill', 1000) then return end

    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 and IsPedInAnyVehicle(ped, false) then
        Notify(source, Config.Lang['cannot_use_in_vehicle'], 'error')
        return
    end

    if Config.Framework == 'qbcore' and not Bridge.IsFrameworkReady() then
        Notify(source, Config.Lang['framework_unavailable'], 'error')
        return
    end
    if (Config.Inventory == 'ox_inventory' or Config.Framework == 'qbcore') and not Bridge.HasItem(source, 'mangal', 1) then
        Notify(source, Config.Lang['no_grill_item'], 'error')
        return
    end

    PendingPlacements[source] = now + (Config.PlacementRequestTimeout or 15000)
    TriggerClientEvent('mangal:client:startPlacingGrill', source)
end

local function RegisterUsableItems()
    if UsableItemsRegistered then return true end
    if Config.Framework == 'qbcore' and not Bridge.IsFrameworkReady() then return false end

    local function RegisterUseableItem(itemName, callback)
        local registered = Bridge.CreateUseableItem(itemName, callback)
        if registered ~= true then
            error(('Kullanilabilir item kaydi basarisiz: %s'):format(tostring(itemName)))
        end
    end

    local success, reason = pcall(function()
        RegisterUseableItem('mangal', function(source)
            BeginGrillPlacement(source)
        end)

        for _, recipe in ipairs(Config.Recipes) do
            local recipeData = recipe

            local function RegisterFoodUse(itemName)
                Bridge.MarkItemUseable(itemName)

                RegisterUseableItem(itemName, function(source, usedItem)
                    local src = source
                    local inventoryItem = usedItem
                    if type(inventoryItem) ~= 'table' then
                        inventoryItem = Bridge.GetItem(src, itemName)
                    end
                    if not inventoryItem or inventoryItem.name ~= itemName then return end

                    local info = Bridge.GetItemInfo(inventoryItem)
                    local seasoningData = info.seasoning and Config.Seasonings[info.seasoning]

                    local poisonChance = GetPoisonChance(inventoryItem, recipeData)
                    if seasoningData and seasoningData.safeCookBonus then
                        poisonChance = math.max(0, poisonChance - seasoningData.safeCookBonus)
                    end
                    local isSafe = math.random(1, 100) > poisonChance

                    if not Bridge.RemoveItem(src, itemName, 1) then return end

                    local hungerAmount = (recipeData.hungerAmount or 0) + (seasoningData and seasoningData.hungerBonus or 0)
                    Bridge.AddHunger(src, hungerAmount)

                    TriggerClientEvent('mangal:client:eatFood', src, {
                        label = recipeData.label,
                        hungerAmount = hungerAmount,
                        healthAmount = recipeData.healthAmount or 0,
                        staminaAmount = recipeData.staminaAmount or 0,
                        isSafe = isSafe
                    })

                    if not isSafe then
                        TriggerFoodPoisoning(src)
                    end
                end)
            end

            RegisterFoodUse(recipeData.rawItem)
            RegisterFoodUse(recipeData.undercookedItem)
            RegisterFoodUse(recipeData.cookedItem)
        end
    end)

    if not success then
        UsableItemsRegistered = false
        print(('^3[mangal_script]^7 Kullanilabilir item kaydi ertelendi: %s'):format(tostring(reason)))
        return false
    end

    UsableItemsRegistered = true
    return true
end

local function EnsureFoodItemDefinitions()
    Config.QBItemDefinitions = Config.QBItemDefinitions or {}

    for _, recipe in ipairs(Config.Recipes) do
        local itemDefinitions = {
            { name = recipe.rawItem, label = 'Raw ' .. recipe.label },
            { name = recipe.undercookedItem, label = 'Undercooked ' .. recipe.label },
            { name = recipe.cookedItem, label = recipe.label }
        }

        for _, item in ipairs(itemDefinitions) do
            if item.name and not Config.QBItemDefinitions[item.name] then
                Config.QBItemDefinitions[item.name] = {
                    name = item.name,
                    label = item.label,
                    weight = 200,
                    type = 'item',
                    image = item.name .. '.png',
                    unique = true,
                    useable = true,
                    shouldClose = true,
                    combinable = nil,
                    description = item.label
                }
            end
        end
    end
end

local function RegisterMissingQBCoreItems()
    EnsureFoodItemDefinitions()
    if Config.Inventory ~= 'qbcore' then return false end
    if Config.Framework ~= 'qbcore' or not Bridge.IsFrameworkReady() then return false end

    local allRegistered = true
    for itemName, itemData in pairs(Config.QBItemDefinitions or {}) do
        if not Bridge.ItemExists(itemName) then
            local added = Bridge.RegisterItem(itemName, itemData)
            if added then
                print(('^2[mangal_script]^7 Eksik QBCore itemi kaydedildi: %s'):format(itemName))
            else
                allRegistered = false
                print(('^3[mangal_script]^7 QBCore item kaydi ertelendi/basarisiz: %s'):format(itemName))
            end
        end
    end

    return allRegistered
end

RegisterMissingQBCoreItems()
RegisterUsableItems()

-- ----------------------------------------------------
-- MANGAL KURMA & TOPLAMA EVENTLERI
-- ----------------------------------------------------
RegisterNetEvent('mangal:server:requestPlaceGrill')
AddEventHandler('mangal:server:requestPlaceGrill', function()
    BeginGrillPlacement(source)
end)

RegisterNetEvent('mangal:server:cancelPlacement')
AddEventHandler('mangal:server:cancelPlacement', function()
    PendingPlacements[source] = nil
end)

RegisterNetEvent('mangal:server:createGrill')
AddEventHandler('mangal:server:createGrill', function(netId)
    local src = source
    local expiresAt = PendingPlacements[src]
    PendingPlacements[src] = nil

    if not expiresAt or expiresAt < GetGameTimer() then
        TriggerClientEvent('mangal:client:placementRejected', src)
        return
    end

    local netIdNum, entity = nil, nil
    for _ = 1, 20 do
        netIdNum, entity = GetGrillEntity(netId, false)
        if entity then break end
        Wait(50)
    end
    if not netIdNum or GrillStates[netIdNum] ~= nil
        or NetworkGetEntityOwner(entity) ~= src
        or not IsPlayerNearEntity(src, entity, Config.GrillInteractDistance or 4.0) then
        TriggerClientEvent('mangal:client:placementRejected', src)
        return
    end

    if not Bridge.RemoveItem(src, 'mangal', 1) then
        TriggerClientEvent('mangal:client:placementRejected', src)
        Notify(src, Config.Lang['no_grill_item'], 'error')
        return
    end

    GrillStates[netIdNum] = 'EMPTY'
    GrillHeat[netIdNum] = 0
    GrillOwners[netIdNum] = Bridge.GetIdentifier(src)
    InitializeGrillSlots(netIdNum)

    TriggerClientEvent('mangal:client:placementApproved', src, netIdNum)
    TriggerClientEvent('mangal:client:syncGrillState', -1, netIdNum, 'EMPTY')
    TriggerClientEvent('mangal:client:syncGrillHeat', -1, netIdNum, 0)
    TriggerClientEvent('mangal:client:syncGrillSlots', -1, netIdNum, GrillSlots[netIdNum])
    Notify(src, Config.Lang['grill_placed'], 'success')
end)

RegisterNetEvent('mangal:server:removeGrill')
AddEventHandler('mangal:server:removeGrill', function(netId)
    local src = source
    if not CanUseEvent(src, 'removeGrill', 1000) then
        ReleaseGrillUse(src, netId, 'mangal:client:grillUseReleased')
        return
    end

    local netIdNum, entity = ValidateRegisteredGrill(src, netId, Config.GrillInteractDistance or 4.0)
    if not netIdNum then
        Notify(src, Config.Lang['invalid_grill'], 'error')
        ReleaseGrillUse(src, netId, 'mangal:client:grillUseReleased')
        return
    end
    if not EnsureGrillUse(src, netIdNum, true) then return end

    if Config.OnlyOwnerCanRemove ~= false and GrillOwners[netIdNum] ~= Bridge.GetIdentifier(src) then
        Notify(src, Config.Lang['not_grill_owner'], 'error')
        ReleaseGrillUse(src, netIdNum, 'mangal:client:grillUseReleased')
        return
    end

    local meatRefunds, meatCount, burntCount = GetGrillMeatRefunds(netIdNum)
    if not meatRefunds then
        Notify(src, Config.Lang['invalid_grill'], 'error')
        ReleaseGrillUse(src, netIdNum, 'mangal:client:grillUseReleased')
        return
    end

    if not GiveGrillAndContents(src, meatRefunds) then
        Notify(src, Config.Lang['inventory_full'], 'error')
        ReleaseGrillUse(src, netIdNum, 'mangal:client:grillUseReleased')
        return
    end

    local entityOwner = NetworkGetEntityOwner(entity)
    if entityOwner and entityOwner > 0 then
        TriggerClientEvent('mangal:client:deleteGrillEntity', entityOwner, netIdNum)
    end
    if entityOwner ~= src then
        TriggerClientEvent('mangal:client:deleteGrillEntity', src, netIdNum)
    end
    DeleteEntity(entity)
    ClearGrillData(netIdNum, true)
    if meatCount > 0 and burntCount > 0 then
        Notify(src, string.format(Config.Lang['grill_removed_with_meat_and_burnt'], meatCount, burntCount), 'success')
    elseif meatCount > 0 then
        Notify(src, string.format(Config.Lang['grill_removed_with_meat'], meatCount), 'success')
    elseif burntCount > 0 then
        Notify(src, string.format(Config.Lang['grill_removed_with_burnt'], burntCount), 'success')
    else
        Notify(src, Config.Lang['grill_removed'], 'success')
    end
end)

-- ----------------------------------------------------
-- KÖMÜR EKLEME & YAKMA (VALIDATED)
-- ----------------------------------------------------
RegisterNetEvent('mangal:server:requestAddCoal')
AddEventHandler('mangal:server:requestAddCoal', function(netId)
    local src = source
    if not CanUseEvent(src, 'requestAddCoal', 500) then return end
    local netIdNum = ValidateRegisteredGrill(src, netId, Config.GrillInteractDistance or 4.0)
    if not netIdNum then
        Notify(src, Config.Lang['invalid_grill'], 'error')
        return
    end
    if not EnsureGrillUse(src, netIdNum, true) then return end

    local currentState = GrillStates[netIdNum]
    if currentState ~= 'EMPTY' then
        Notify(src, Config.Lang['already_has_coal'], 'error')
        return
    end

    local coalItem = Bridge.GetFirstMatchingItem(src, Config.CoalItems)
    if not coalItem then
        Notify(src, Config.Lang['need_coal'], 'error')
        return
    end

    if not BeginAction(src, 'addCoal', netIdNum, Config.AddCoalTime or 3000) then
        Notify(src, Config.Lang['action_in_progress'], 'error')
        return
    end
    TriggerClientEvent('mangal:client:startAddCoal', src, netIdNum)
end)

RegisterNetEvent('mangal:server:finishAddCoal')
AddEventHandler('mangal:server:finishAddCoal', function(netId)
    local src = source
    local netIdNum = NormalizeNetId(netId)
    if not netIdNum or not CompleteAction(src, 'addCoal', netIdNum) then return end
    netIdNum = ValidateRegisteredGrill(src, netIdNum, Config.GrillInteractDistance or 4.0)
    if not netIdNum then return end
    if not HasGrillUse(src, netIdNum, true) then return end

    local currentState = GrillStates[netIdNum]
    if currentState ~= 'EMPTY' then return end

    local coalItem = Bridge.GetFirstMatchingItem(src, Config.CoalItems)
    if not coalItem then
        Notify(src, Config.Lang['need_coal'], 'error')
        return
    end

    if not Bridge.RemoveItem(src, coalItem, 1) then
        Notify(src, Config.Lang['need_coal'], 'error')
        return
    end

    GrillStates[netIdNum] = 'HAS_COAL'
    GrillCoalType[netIdNum] = coalItem
    if not GrillSlots[netIdNum] then InitializeGrillSlots(netIdNum) end

    TriggerClientEvent('mangal:client:syncGrillState', -1, netIdNum, 'HAS_COAL')
    TriggerClientEvent('mangal:client:syncGrillHeat', -1, netIdNum, 0)
    Notify(src, Config.Lang['coal_added'], 'success')
end)

RegisterNetEvent('mangal:server:requestLightGrill')
AddEventHandler('mangal:server:requestLightGrill', function(netId)
    local src = source
    if not CanUseEvent(src, 'requestLightGrill', 500) then return end
    local netIdNum = ValidateRegisteredGrill(src, netId, Config.GrillInteractDistance or 4.0)
    if not netIdNum then
        Notify(src, Config.Lang['invalid_grill'], 'error')
        return
    end
    if not EnsureGrillUse(src, netIdNum, true) then return end

    local currentState = GrillStates[netIdNum]
    if currentState == 'EMPTY' or not currentState then
        Notify(src, Config.Lang['need_coal'], 'error')
        return
    elseif currentState == 'LIT' then
        Notify(src, Config.Lang['already_lit'], 'error')
        return
    end

    local ignitionItem = Bridge.GetFirstMatchingItem(src, Config.IgnitionItems)
    if not ignitionItem then
        Notify(src, Config.Lang['need_ignition'], 'error')
        return
    end

    if not BeginAction(src, 'lightGrill', netIdNum, Config.LightGrillTime or 5000) then
        Notify(src, Config.Lang['action_in_progress'], 'error')
        return
    end
    TriggerClientEvent('mangal:client:startLightGrill', src, netIdNum)
end)

RegisterNetEvent('mangal:server:finishLightGrill')
AddEventHandler('mangal:server:finishLightGrill', function(netId)
    local src = source
    local netIdNum = NormalizeNetId(netId)
    if not netIdNum or not CompleteAction(src, 'lightGrill', netIdNum) then return end
    netIdNum = ValidateRegisteredGrill(src, netIdNum, Config.GrillInteractDistance or 4.0)
    if not netIdNum then return end
    if not HasGrillUse(src, netIdNum, true) then return end

    local currentState = GrillStates[netIdNum]
    if currentState ~= 'HAS_COAL' then return end

    local ignitionItem = Bridge.GetFirstMatchingItem(src, Config.IgnitionItems)
    if not ignitionItem then
        Notify(src, Config.Lang['need_ignition'], 'error')
        return
    end

    local coalData = GrillCoalType[netIdNum] and Config.CoalTypes and Config.CoalTypes[GrillCoalType[netIdNum]]
    local igniteBonus = (coalData and tonumber(coalData.igniteBonus)) or 0

    GrillStates[netIdNum] = 'LIT'
    GrillHeat[netIdNum] = math.min(Config.MaxHeat or 100, (Config.DefaultHeat or 50) + igniteBonus)
    if not GrillSlots[netIdNum] then InitializeGrillSlots(netIdNum) end

    TriggerClientEvent('mangal:client:syncGrillState', -1, netIdNum, 'LIT')
    TriggerClientEvent('mangal:client:syncGrillHeat', -1, netIdNum, GrillHeat[netIdNum])
    TriggerClientEvent('mangal:client:syncGrillSlots', -1, netIdNum, GrillSlots[netIdNum])
    Notify(src, Config.Lang['grill_lit'], 'success')
end)

-- ----------------------------------------------------
-- ATEŞİ YELPAZELEME
-- ----------------------------------------------------
RegisterNetEvent('mangal:server:requestFanGrill')
AddEventHandler('mangal:server:requestFanGrill', function(netId)
    local src = source
    if not CanUseEvent(src, 'requestFanGrill', 500) then return end
    local netIdNum = ValidateRegisteredGrill(src, netId, Config.GrillInteractDistance or 4.0)
    if not netIdNum then return end
    if not EnsureGrillUse(src, netIdNum, true) then return end

    local currentState = GrillStates[netIdNum]
    if currentState ~= 'LIT' then return end

    local now = GetGameTimer()
    FanCooldowns[src] = FanCooldowns[src] or {}
    if (FanCooldowns[src][netIdNum] or 0) > now then
        Notify(src, Config.Lang['fan_cooldown'], 'error')
        return
    end

    if not BeginAction(src, 'fanGrill', netIdNum, Config.FanMinimumDuration or 1000) then
        Notify(src, Config.Lang['action_in_progress'], 'error')
        return
    end
    TriggerClientEvent('mangal:client:startFanning', src, netIdNum)
end)

RegisterNetEvent('mangal:server:finishFanning')
AddEventHandler('mangal:server:finishFanning', function(netId, isSuccess)
    local src = source
    local netIdNum = NormalizeNetId(netId)
    if not netIdNum or not CompleteAction(src, 'fanGrill', netIdNum) then return end
    netIdNum = ValidateRegisteredGrill(src, netIdNum, Config.GrillInteractDistance or 4.0)
    if not netIdNum then return end
    if not HasGrillUse(src, netIdNum, true) then return end

    local currentState = GrillStates[netIdNum]
    if currentState ~= 'LIT' then return end

    FanCooldowns[src] = FanCooldowns[src] or {}
    local now = GetGameTimer()
    if (FanCooldowns[src][netIdNum] or 0) > now then return end
    FanCooldowns[src][netIdNum] = now + (Config.FanCooldown or 5000)

    local currentHeat = GrillHeat[netIdNum] or Config.DefaultHeat or 50
    local newHeat = currentHeat

    if isSuccess == true then
        newHeat = math.min(Config.MaxHeat or 100, currentHeat + (Config.FanHeatGain or 20))
        UpdateLitGrillHeat(netIdNum, newHeat)
        Notify(src, string.format(Config.Lang['heat_fanned'], newHeat), 'success')
    else
        newHeat = math.max(Config.MinHeat or 0, currentHeat - (Config.FanHeatLossOnFail or 5))
        UpdateLitGrillHeat(netIdNum, newHeat)
        Notify(src, string.format(Config.Lang['heat_fan_failed'], newHeat), 'error')
    end
end)

RegisterNetEvent('mangal:server:cancelAction')
AddEventHandler('mangal:server:cancelAction', function(action, netId)
    if action ~= 'addCoal' and action ~= 'lightGrill' and action ~= 'fanGrill' then return end
    local netIdNum = NormalizeNetId(netId)
    if netIdNum then CancelAction(source, action, netIdNum) end
end)

-- ----------------------------------------------------
-- SLOT YÖNETİMİ: ET EKLEME (ADD MEAT TO SLOT)
-- ----------------------------------------------------
RegisterNetEvent('mangal:server:requestAddMeat')
AddEventHandler('mangal:server:requestAddMeat', function(netId, recipeId, targetSlot, seasoningId)
    local src = source
    if not CanUseEvent(src, 'requestAddMeat', 300) then return end
    local netIdNum = ValidateRegisteredGrill(src, netId, Config.GrillInteractDistance or 4.0)
    if not netIdNum then
        Notify(src, Config.Lang['invalid_grill'], 'error')
        return
    end
    if not EnsureGrillUse(src, netIdNum, true) then return end

    local state = GrillStates[netIdNum]
    if state ~= 'LIT' then
        Notify(src, Config.Lang['need_ignition'], 'error')
        return
    end
    if not GrillSlots[netIdNum] then
        InitializeGrillSlots(netIdNum)
    end

    local recipe = GetRecipeById(recipeId)
    if not recipe then return end

    -- Oyuncu envanter kontrolü
    if not Bridge.HasItem(src, recipe.rawItem, 1) then
        Notify(src, Config.Lang['no_raw_item_in_inventory'], 'error')
        return
    end

    -- Baharat (opsiyonel) kontrolü
    local seasoningKey = nil
    if seasoningId and Config.Seasonings and Config.Seasonings[seasoningId] then
        if not Bridge.HasItem(src, seasoningId, 1) then
            Notify(src, Config.Lang['no_seasoning_in_inventory'], 'error')
            return
        end
        seasoningKey = seasoningId
    end

    -- Boş slot bulma
    local maxSlots = Config.MaxSlots or 6
    local chosenSlot = nil

    local tSlot = tonumber(targetSlot)
    if tSlot and tSlot >= 1 and tSlot <= maxSlots then
        if not GrillSlots[netIdNum][tSlot].isOccupied then
            chosenSlot = tSlot
        end
    end

    if not chosenSlot then
        for i = 1, maxSlots do
            if not GrillSlots[netIdNum][i].isOccupied then
                chosenSlot = i
                break
            end
        end
    end

    if not chosenSlot then
        Notify(src, string.format(Config.Lang['grill_full'], maxSlots), 'error')
        return
    end

    if not Bridge.RemoveItem(src, recipe.rawItem, 1) then
        Notify(src, Config.Lang['no_raw_item_in_inventory'], 'error')
        return
    end

    if seasoningKey and not Bridge.RemoveItem(src, seasoningKey, 1) then
        seasoningKey = nil
    end

    -- Slota Yerleştir
    GrillSlots[netIdNum][chosenSlot] = {
        isOccupied = true,
        item = recipe.id,
        status = 'RAW',
        cookProgress = 0,
        seasoning = seasoningKey,
        isBusy = false
    }

    TriggerClientEvent('mangal:client:syncGrillSlots', -1, netIdNum, GrillSlots[netIdNum])
    Notify(src, string.format(Config.Lang['meat_placed'], recipe.label, chosenSlot), 'success')
    if seasoningKey then
        Notify(src, string.format(Config.Lang['seasoning_added'], Config.Seasonings[seasoningKey].label), 'success')
    end
end)

-- ----------------------------------------------------
-- SLOT YÖNETİMİ: ETİ ÇEVİR / TOPLA (PICK MEAT FROM SLOT)
-- ----------------------------------------------------
RegisterNetEvent('mangal:server:requestRecipeAvailability')
AddEventHandler('mangal:server:requestRecipeAvailability', function(requestId, netId, targetSlot)
    local src = source
    local netIdNum = ValidateRegisteredGrill(src, netId, Config.GrillInteractDistance or 4.0)
    if not netIdNum or not HasGrillUse(src, netIdNum, true) then return end
    local availability = {}
    local seasoningAvailability = {}

    for _, recipe in ipairs(Config.Recipes) do
        availability[recipe.id] = Bridge.HasItem(src, recipe.rawItem, 1)
    end

    for seasoningId in pairs(Config.Seasonings or {}) do
        seasoningAvailability[seasoningId] = Bridge.HasItem(src, seasoningId, 1)
    end

    TriggerClientEvent(
        'mangal:client:recipeAvailability',
        src,
        requestId,
        netIdNum,
        targetSlot,
        availability,
        seasoningAvailability
    )
end)

RegisterNetEvent('mangal:server:requestPickMeat')
AddEventHandler('mangal:server:requestPickMeat', function(netId, slotIndex, keepMenuOpen)
    local src = source
    if not CanUseEvent(src, 'requestPickMeat', 300) then
        if keepMenuOpen ~= true then
            ReleaseGrillUse(src, netId, 'mangal:client:grillUseReleased')
        end
        return
    end
    local netIdNum = ValidateRegisteredGrill(src, netId, Config.GrillInteractDistance or 4.0)
    local idx = tonumber(slotIndex)
    if not netIdNum or not idx or idx ~= math.floor(idx) then
        if keepMenuOpen ~= true then
            ReleaseGrillUse(src, netId, 'mangal:client:grillUseReleased')
        end
        return
    end
    if not EnsureGrillUse(src, netIdNum, true) then return end

    local keepPickLock = false
    local function ReleasePickLock()
        if not keepPickLock then
            ReleaseGrillUse(src, netIdNum, 'mangal:client:grillUseReleased')
        end
    end

    if not GrillSlots[netIdNum] or not GrillSlots[netIdNum][idx] then
        ReleasePickLock()
        return
    end

    local slot = GrillSlots[netIdNum][idx]
    if not slot.isOccupied then
        ReleasePickLock()
        return
    end

    -- Server Validation & Mutex / Anti-Dupe Lock
    if slot.isBusy then
        Notify(src, Config.Lang['slot_busy'], 'error')
        ReleasePickLock()
        return
    end

    slot.isBusy = true

    local recipe = GetRecipeById(slot.item)
    if not recipe then
        slot.isBusy = false
        ReleasePickLock()
        return
    end

    if slot.status == 'BURNT' then
        keepPickLock = keepMenuOpen == true
        GrillSlots[netIdNum][idx] = NewEmptySlot()

        TriggerClientEvent('mangal:client:syncGrillSlots', -1, netIdNum, GrillSlots[netIdNum])
        Notify(src, string.format(Config.Lang['burnt_meat_discarded'], idx), 'error')
        ReleasePickLock()
        return
    end

    local targetItem = GetSlotRewardItem(slot)
    if not targetItem then
        slot.isBusy = false
        ReleasePickLock()
        return
    end

    local foodInfo = BuildFoodInfo(recipe, slot, targetItem)
    if not Bridge.AddItem(src, targetItem, 1, foodInfo) then
        slot.isBusy = false
        Notify(src, Config.Lang['inventory_full'], 'error')
        ReleasePickLock()
        return
    end

    -- Slot Sıfırlama
    GrillSlots[netIdNum][idx] = NewEmptySlot()

    TriggerClientEvent('mangal:client:syncGrillSlots', -1, netIdNum, GrillSlots[netIdNum])
    Notify(src, string.format(Config.Lang['meat_picked'], idx, recipe.label), 'success')
    ReleasePickLock()
end)

AddEventHandler('playerDropped', function()
    local src = source
    ReleaseGrillUse(src, PlayerGrillLocks[src])
    PendingPlacements[src] = nil
    PendingActions[src] = nil
    EventCooldowns[src] = nil
    FanCooldowns[src] = nil
    PoisonedPlayers[src] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= 'qb-core' or Config.Framework ~= 'qbcore' then return end

    Bridge.MarkCoreLost()
    UsableItemsRegistered = false

    CreateThread(function()
        for _ = 1, 20 do
            Wait(250)
            if GetResourceState('qb-core') == 'started' and Bridge.RefreshCore() then
                if RegisterMissingQBCoreItems() and RegisterUsableItems() then return end
                Bridge.MarkCoreLost()
                UsableItemsRegistered = false
            end
        end

        print('^1[mangal_script]^7 qb-core restart sonrasi yeniden baglanilamadi; mangal_script restart edilmeli.')
    end)
end)

CreateThread(function()
    while true do
        Wait(30000)
        for netId in pairs(GrillStates) do
            local _, entity = GetGrillEntity(netId, true)
            if not entity then ClearGrillData(netId, true) end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == 'qb-core' then
        Bridge.MarkCoreLost()
        UsableItemsRegistered = false
        return
    end

    if resourceName ~= GetCurrentResourceName() then return end
    for netId in pairs(GrillStates) do
        local _, entity = GetGrillEntity(netId, true)
        if entity then DeleteEntity(entity) end
    end
end)
