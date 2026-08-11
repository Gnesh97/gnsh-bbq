-- ====================================================
-- BRIDGE_CLIENT.LUA - Framework Soyutlama Katmani (CLIENT)
--
-- client.lua hicbir zaman dogrudan QBCore.Functions.* cagirmaz;
-- sadece ClientBridge.* kullanir. Bildirim/ilerleme cubugu/minigame
-- stilleri zaten Config.NotifyStyle / Config.MinigameSystem uzerinden
-- secilir; bu dosya sadece o secimlerin gercek cagrilarini toplar.
-- Baska bir core'a gecerken SADECE bu dosya (ve bridge.lua) degisir.
-- ====================================================

ClientBridge = {}

local QBCore = nil

local function TryGetQBCore()
    if Config.Framework ~= 'qbcore' then return false end
    local coreObject = nil
    local success = pcall(function()
        coreObject = exports['qb-core']:GetCoreObject()
    end)
    QBCore = success and coreObject or nil
    return QBCore ~= nil
end

TryGetQBCore()

function ClientBridge.RefreshCore()
    return TryGetQBCore()
end

-- ----------------------------------------------------
-- BILDIRIM
-- ----------------------------------------------------
function ClientBridge.Notify(msg, notifyType, force)
    if Config.EnableNotifications == false and not force then return end

    local style = Config.NotifyStyle or 'qbcore'

    if style == 'qbcore' and QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg, notifyType or 'primary')
    elseif style == 'ox_lib' and GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:notify({
            description = msg,
            type = notifyType or 'info'
        })
    elseif style == 'gta' then
        SetNotificationTextEntry('STRING')
        AddTextComponentSubstringPlayerName(msg)
        DrawNotification(false, false)
    end
end

-- ----------------------------------------------------
-- ILERLEME CUBUGU (kömür ekleme / yakma)
-- QBCore Progressbar yoksa duz Wait ile devam eder; script hicbir
-- zaman aksiyonu tamamlamadan takilip kalmaz.
-- ----------------------------------------------------
function ClientBridge.Progressbar(name, label, duration, disableControls, onFinish, onCancel)
    if QBCore and QBCore.Functions and QBCore.Functions.Progressbar then
        QBCore.Functions.Progressbar(name, label, duration, false, true, disableControls or {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, onFinish, onCancel)
    else
        Wait(duration)
        if onFinish then onFinish() end
    end
end

-- ----------------------------------------------------
-- STANDALONE YELPAZELEME MINIGAME'I (A/D bar doldurma)
-- Oyuncu A ve D tuslarina SIRAYLA basarak bari doldurur; bar sure
-- ilerledikce kendi kendine azalir (decay). Bar %100 olursa basari,
-- sure dolarsa basarisizlik doner.
-- ----------------------------------------------------
local function FanMinigameStandalone()
    local timeLimit = Config.FanBarTimeLimit or 6000
    local fillPerPress = Config.FanBarFillPerPress or 9
    local decayPerSecond = Config.FanBarDecayPerSecond or 7

    SendNUIMessage({ action = 'openFanMinigame' })

    local startTime = GetGameTimer()
    local lastTick = startTime
    local lastSentPercent = -1
    local percent = 0
    local expectedKey = nil -- ilk basis A ya da D olabilir
    local success = false

    while true do
        Wait(0)
        local now = GetGameTimer()
        local dt = now - lastTick
        lastTick = now

        -- Hareketi kilitle, sadece A/D basisi minigame icin okunsun
        DisableControlAction(0, 30, true) -- MOVE_LEFT_RIGHT
        DisableControlAction(0, 31, true) -- MOVE_UP_DOWN
        DisableControlAction(0, 32, true) -- MOVE_UP_ONLY
        DisableControlAction(0, 33, true) -- MOVE_DOWN_ONLY
        DisableControlAction(0, 34, true) -- MOVE_LEFT_ONLY (A)
        DisableControlAction(0, 35, true) -- MOVE_RIGHT_ONLY (D)

        local pressedKey = nil
        if IsDisabledControlJustPressed(0, 34) then
            pressedKey = 'a'
        elseif IsDisabledControlJustPressed(0, 35) then
            pressedKey = 'd'
        end

        if pressedKey then
            if expectedKey == nil or pressedKey == expectedKey then
                percent = math.min(100, percent + fillPerPress)
                expectedKey = (pressedKey == 'a') and 'd' or 'a'
            else
                -- Sirayi bozan (ayni tusa ust uste basilan) basis da yari
                -- oranda ilerleme versin; spam korumasi tamamen sifir vermesin.
                percent = math.min(100, percent + (fillPerPress * 0.5))
            end
        end

        -- Bar zaten dolduysa basari kontrolunden once decay uygulanmasin,
        -- yoksa ayni karede dolan bar hemen geri dusup basariyi kacirir.
        if percent >= 100 then
            success = true
        elseif percent > 0 then
            percent = math.max(0, percent - (decayPerSecond * dt / 1000))
        end

        if pressedKey or math.abs(percent - lastSentPercent) >= 1 then
            lastSentPercent = percent
            SendNUIMessage({ action = 'updateFanMinigame', percent = math.floor(percent + 0.5), lastKey = pressedKey })
        end

        if success then
            break
        end

        if (now - startTime) >= timeLimit then
            success = false
            break
        end
    end

    SendNUIMessage({ action = 'closeFanMinigame', success = success })
    return success
end

-- ----------------------------------------------------
-- YELPAZELEME MINIGAME'I (basari/basarisizlik bool doner)
-- Config.MinigameSystem: 'standalone' | 'qb-skillbar' | 'ox_lib' (yoksa Progressbar fallback)
-- ----------------------------------------------------
function ClientBridge.FanMinigame()
    if Config.MinigameSystem == 'qb-skillbar' and GetResourceState('qb-skillbar') == 'started' then
        local p = promise.new()
        local Skillbar = exports['qb-skillbar']:GetSkillbarObject()
        Skillbar.Start({
            duration = math.random(2000, 3000),
            pos = math.random(10, 30),
            width = math.random(12, 20)
        }, function()
            p:resolve(true)
        end, function()
            p:resolve(false)
        end)
        return Citizen.Await(p)
    end

    if Config.MinigameSystem == 'ox_lib' and GetResourceState('ox_lib') == 'started' then
        return exports.ox_lib:skillCheck({ 'easy', 'easy' }, { 'e' }) and true or false
    end

    if Config.MinigameSystem == 'standalone' then
        return FanMinigameStandalone()
    end

    local p = promise.new()
    ClientBridge.Progressbar("mangal_fan", Config.Lang['target_fan'], 2500, nil, function()
        p:resolve(true)
    end, function()
        p:resolve(false)
    end)
    return Citizen.Await(p)
end
