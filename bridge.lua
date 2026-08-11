-- ====================================================
-- BRIDGE.LUA - Framework / Envanter Soyutlama Katmani (SUNUCU)
--
-- server.lua hicbir zaman QBCore.* veya Player.Functions.* cagirmaz;
-- sadece Bridge.* fonksiyonlarini kullanir. Yarin ESX / ox_core veya
-- ox_inventory / qs-inventory gibi baska bir sisteme gecmek istenirse
-- SADECE bu dosyanin govdesi degistirilir, server.lua'ya dokunulmaz.
--
-- Envanter kontrolu Config.Inventory'e gore yapilir ('ox_inventory' veya
-- 'qbcore'), Config.Framework'ten bagimsizdir. Ikisi de eslesmezse
-- (bilinmeyen/standalone envanter) fonksiyonlar "basarili" gibi davranir.
-- ====================================================

Bridge = {}

local QBCore = nil

local function TryGetQBCore()
    if Config.Framework ~= 'qbcore' then return false end
    local coreObject = nil
    local success = pcall(function()
        coreObject = exports['qb-core']:GetCoreObject()
    end)

    -- qb-core restart edilirken eski obje icindeki fonksiyon referanslari
    -- gecersiz olur. Export henuz hazir degilse eski objeyi kullanma.
    QBCore = success and coreObject or nil
    if not QBCore then
        TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
    end
    return QBCore ~= nil
end

TryGetQBCore()

-- ----------------------------------------------------
-- CORE ERISIMI
-- ----------------------------------------------------
function Bridge.GetCore()
    return QBCore
end

function Bridge.RefreshCore()
    return TryGetQBCore()
end

function Bridge.IsFrameworkReady()
    if Config.Framework ~= 'qbcore' then return true end
    return QBCore ~= nil
end

function Bridge.MarkCoreLost()
    QBCore = nil
end

-- ----------------------------------------------------
-- OYUNCU / KIMLIK
-- ----------------------------------------------------
function Bridge.GetPlayer(source)
    if Config.Framework ~= 'qbcore' then return nil end
    if not QBCore or not QBCore.Functions then return nil end
    return QBCore.Functions.GetPlayer(source)
end

-- Karaktere baglı kalıcı kimlik. Baska bir core'a gecilirse burasi
-- (ornegin ESX identifier'i) tek degisecek yer olur.
function Bridge.GetIdentifier(source)
    local Player = Bridge.GetPlayer(source)
    if Player and Player.PlayerData and Player.PlayerData.citizenid then
        return Player.PlayerData.citizenid
    end
    return GetPlayerIdentifierByType(source, 'license') or GetPlayerIdentifier(source, 0) or tostring(source)
end

-- ----------------------------------------------------
-- ENVANTER
-- Config.Inventory: 'ox_inventory' veya 'qbcore'. Framework'ten bagimsiz
-- calisir (ornegin QBCore + ox_inventory kombinasyonu desteklenir).
-- ----------------------------------------------------
local function IsOxInventory()
    return Config.Inventory == 'ox_inventory'
end

local function IsQBInventory()
    return Config.Inventory == 'qbcore' or (Config.Inventory == nil and Config.Framework == 'qbcore')
end

function Bridge.GetItem(source, itemName)
    if IsOxInventory() then
        local items = exports.ox_inventory:Search(source, 'slots', itemName)
        return items and items[1] or nil
    end

    local Player = Bridge.GetPlayer(source)
    if not Player or not Player.Functions then return nil end
    return Player.Functions.GetItemByName(itemName)
end

function Bridge.GetItemCount(source, itemName)
    if IsOxInventory() then
        return tonumber(exports.ox_inventory:Search(source, 'count', itemName)) or 0
    end

    local item = Bridge.GetItem(source, itemName)
    if not item then return 0 end
    return tonumber(item.amount or item.count or (item[1] and item[1].amount)) or 0
end

function Bridge.HasItem(source, itemName, amount)
    if not IsOxInventory() and not IsQBInventory() then return true end
    return Bridge.GetItemCount(source, itemName) >= (amount or 1)
end

function Bridge.GetFirstMatchingItem(source, itemList)
    if not IsOxInventory() and not IsQBInventory() then return itemList[1] end
    for _, itemName in ipairs(itemList) do
        if Bridge.GetItemCount(source, itemName) > 0 then
            return itemName
        end
    end
    return nil
end

function Bridge.ShowItemBox(source, itemName, action)
    -- ox_inventory kendi ekleme/cikarma bildirimini otomatik gosterir.
    if not IsQBInventory() then return end
    if not QBCore or not QBCore.Shared or not QBCore.Shared.Items then return end
    local itemData = QBCore.Shared.Items[itemName]
    if itemData then
        TriggerClientEvent('inventory:client:ItemBox', source, itemData, action)
    end
end

function Bridge.RemoveItem(source, itemName, amount)
    if IsOxInventory() then
        local before = Bridge.GetItemCount(source, itemName)
        if before < amount then return false end
        return exports.ox_inventory:RemoveItem(source, itemName, amount) and true or false
    end

    if not IsQBInventory() then return true end
    local Player = Bridge.GetPlayer(source)
    if not Player then return false end

    local before = Bridge.GetItemCount(source, itemName)
    if before < amount then return false end
    local result = Player.Functions.RemoveItem(itemName, amount)
    local removed = result == true or Bridge.GetItemCount(source, itemName) <= before - amount
    if removed then Bridge.ShowItemBox(source, itemName, 'remove') end
    return removed
end

function Bridge.AddItem(source, itemName, amount, info, slot)
    if IsOxInventory() then
        return exports.ox_inventory:AddItem(source, itemName, amount, info) and true or false
    end

    if not IsQBInventory() then return true end
    local Player = Bridge.GetPlayer(source)
    if not Player then return false end

    local before = Bridge.GetItemCount(source, itemName)
    local result = Player.Functions.AddItem(itemName, amount, slot, info)
    local added = result == true or Bridge.GetItemCount(source, itemName) >= before + amount
    if added then Bridge.ShowItemBox(source, itemName, 'add') end
    return added
end

function Bridge.GetItemInfo(item)
    if not item then return {} end
    return item.metadata or item.info or {}
end

-- ----------------------------------------------------
-- IHTIYAC (HUNGER) & USABLE ITEMS
-- ----------------------------------------------------
function Bridge.GetHunger(source)
    local Player = Bridge.GetPlayer(source)
    if not Player or not Player.PlayerData then return 50 end
    return Player.PlayerData.metadata['hunger'] or 50
end

function Bridge.AddHunger(source, amount)
    if Config.Framework ~= 'qbcore' then return end
    local Player = Bridge.GetPlayer(source)
    if not Player then return end

    local newHunger = math.min(100, (Player.PlayerData.metadata['hunger'] or 50) + (amount or 0))
    Player.Functions.SetMetaData('hunger', newHunger)
    TriggerClientEvent('hud:client:UpdateNeeds', source, newHunger, Player.PlayerData.metadata['thirst'])
    return newHunger
end

function Bridge.CreateUseableItem(itemName, cb)
    -- ox_inventory'nin qb-core bridge fork'u item kullanimini kendi export
    -- sistemi yerine QBCore.Functions.CanUseItem kaydina yonlendirir
    -- (ox_inventory/modules/bridge/qb/server.lua: server.UseItem). Bu yuzden
    -- QBCore framework mevcutken envanter ne olursa olsun QBCore uzerinden
    -- kayit yapilmali; export'a dayanan yol yalnizca saf standalone + ox
    -- (QBCore olmadan) icin fallback olarak kalir.
    if Config.Framework == 'qbcore' then
        if not QBCore or not QBCore.Functions or not QBCore.Functions.CreateUseableItem then return false end
        local ok = pcall(function()
            QBCore.Functions.CreateUseableItem(itemName, cb)
        end)
        return ok
    end

    if IsOxInventory() then
        if GetResourceState('ox_inventory') ~= 'started' then return false end
        local ok = pcall(function()
            exports(itemName, function(event, item, inventory, slot, data)
                if event ~= 'usingItem' then return end
                cb(inventory.id, item)
            end)
        end)
        return ok
    end

    return false
end

function Bridge.MarkItemUseable(itemName)
    -- ox_inventory: useable/unique bayraklari data/items.lua icinde statik
    -- tanimlanir, calisma zamaninda degistirilemez.
    if not IsQBInventory() then return end
    if QBCore and QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[itemName] then
        -- Her parca kendi cookProgress/seasoning metadata'sini korumali.
        QBCore.Shared.Items[itemName].useable = true
        QBCore.Shared.Items[itemName].unique = true
    end
end

function Bridge.ItemExists(itemName)
    if IsOxInventory() then
        return exports.ox_inventory:Items(itemName) ~= nil
    end
    if not IsQBInventory() then return true end
    return QBCore and QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[itemName] ~= nil
end

function Bridge.RegisterItem(itemName, itemData)
    if IsOxInventory() then
        -- ox_inventory itemleri resource'un data/items.lua dosyasinda
        -- statik tanimlanir; calisma zamaninda kayit desteklenmez.
        return Bridge.ItemExists(itemName)
    end

    if not IsQBInventory() then return true end
    if not QBCore or not QBCore.Shared or not QBCore.Shared.Items then return false end
    if not QBCore.Functions or not QBCore.Functions.AddItem then return false end

    local callWorked, added = pcall(function()
        return QBCore.Functions.AddItem(itemName, itemData)
    end)
    return callWorked and added == true
end

-- ----------------------------------------------------
-- BILDIRIM
-- ----------------------------------------------------
function Bridge.Notify(source, message, notifyType)
    TriggerClientEvent('mangal:client:notify', source, message, notifyType)
end
