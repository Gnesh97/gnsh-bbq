-- ====================================================
-- CLIENT.LUA - Mangal Script (Durum Yönetimi, PTFX, Slot, Target & Visual Sync)
-- ====================================================

local isCooking = false
local GrillStates = {}   -- Key: netId (number), Value: 'EMPTY' | 'HAS_COAL' | 'LIT'
local GrillHeat = {}     -- Key: netId (number), Value: heat (10 to 100)
local GrillSlots = {}    -- Key: netId (number/string), Value: Array of slots [1..MaxSlots]
local OwnedGrills = {}   -- Yalnizca bu oyuncunun kurdugu mangallar
local SlotProps = {}     -- Key: netId (number/string), Value: Array of attached entities [slotIndex] = handle
local SlotSmokePtfx = {} -- Key: netId, Value: smoke handles by slot index
local ActivePtfx = {}    -- Key: netId (number), Value: { fire = handle, smoke = handle }
local ActiveSounds = {}  -- Key: netId (number), Value: soundId (string)
local pendingPlacementEntity = nil
local isPoisoned = false


-- Slot menusu durumu. DIKKAT: Bunlar dosyanin EN USTUNDE tanimli olmali.
-- Asagida (syncGrillSlots icinde) okunuyorlar; daha gec tanimlanirlarsa
-- oradaki referanslar local'e degil, nil olan global'e baglanir.
local activeSlotMenuNetId = nil
local isSlotMenuOpen = false
local slotMenuSignature = nil
local openSlotMenu -- ileri bildirim; govdesi asagida atanir

-- Ozel NUI menu durumu (Config.UseNuiMenus)
local isNuiMenuOpen = false
local nuiMenuNetId = nil
local nuiMenuView = nil -- 'slots' | 'recipes'
local nuiMeatMenuRequestId = 0
local pendingNuiMeatMenuRequest = nil
local grillUseRequestId = 0
local pendingGrillUseRequest = nil
local activeGrillUseNetId = nil
local nuiGrillPoseActive = false
local nuiGrillPoseNetId = nil
local nuiGrillPoseToken = 0
local nuiGrillPoseAnimReady = false
local nuiGrillHandProp = nil
local FacePedToGrill
local StartNuiGrillHandProp
local StopNuiGrillHandProp
local StartNuiGrillPose
local StopNuiGrillPose
local ResumeNuiGrillPose
local RefreshNuiSlotMenu -- ileri bildirim; govdesi asagida atanir
local RequestNuiGrillUse
local ReleaseNuiGrillUse

-- ----------------------------------------------------
-- YARDIMCI FONKSİYONLAR
-- ----------------------------------------------------
local function GetRecipeById(recipeId)
    for _, recipe in ipairs(Config.Recipes) do
        if recipe.id == recipeId then
            return recipe
        end
    end
    return Config.Recipes[1]
end

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 120)
    end
end

local function ShowNotification(msg, notifyType, force)
    ClientBridge.Notify(msg, notifyType, force)
end

local function LoadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        local timeout = 0
        while not HasAnimDictLoaded(dict) and timeout < 30 do
            Wait(20)
            timeout = timeout + 1
        end
    end
    return HasAnimDictLoaded(dict)
end

local function LoadPtfxDict(dict)
    if not dict or dict == '' then return false end
    local timeout = 0
    while not HasNamedPtfxAssetLoaded(dict) and timeout < 200 do
        RequestNamedPtfxAsset(dict)
        Wait(10)
        timeout = timeout + 1
    end
    return HasNamedPtfxAssetLoaded(dict)
end

local function EnsureModelLoaded(modelHash)
    if not modelHash then return false end
    if HasModelLoaded(modelHash) then return true end
    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then return false end

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 40 do
        Wait(10)
        timeout = timeout + 1
    end
    return HasModelLoaded(modelHash)
end

local function LoadModelSafely(modelHash)
    return EnsureModelLoaded(modelHash)
end

local function GetValidGrillModel()
    local model = Config.GrillModel
    if not EnsureModelLoaded(model) then
        model = `prop_bbq_5`
        if not EnsureModelLoaded(model) then
            model = `prop_bbq_02`
            EnsureModelLoaded(model)
        end
    end
    return model
end

-- ----------------------------------------------------
-- VISUAL SLOT PROP SYSTEM (ATTACHED ENTITY SYNC)
-- ----------------------------------------------------
local function StopSlotSmoke(netId, slotIndex)
    local netIdNum = tonumber(netId) or netId
    local smokeSlots = SlotSmokePtfx[netIdNum] or SlotSmokePtfx[netId]
    local smoke = smokeSlots and smokeSlots[slotIndex]
    if smoke and smoke.handle then
        StopParticleFxLooped(smoke.handle, 0)
    end
    if smokeSlots then
        smokeSlots[slotIndex] = nil
    end
end

local function StopAllSlotSmoke(netId)
    local netIdNum = tonumber(netId) or netId
    local smokeSlots = SlotSmokePtfx[netIdNum] or SlotSmokePtfx[netId]
    if not smokeSlots then return end

    for slotIndex, smoke in pairs(smokeSlots) do
        if smoke and smoke.handle then
            StopParticleFxLooped(smoke.handle, 0)
        end
    end
    SlotSmokePtfx[netIdNum] = nil
    SlotSmokePtfx[netId] = nil
end

local function GetMeatSmokeProfile(status)
    if status == 'COOKED' then
        return Config.CookedMeatSmoke
    elseif status == 'BURNT' then
        return Config.BurntMeatSmoke
    end
    return nil
end

local function UpdateSlotSmoke(netId, slotIndex, slotData, propEntity, grillObj, playerCoords, grillCoords)
    local netIdNum = tonumber(netId) or netId
    local status = slotData and slotData.status
    local profile = GetMeatSmokeProfile(status)
    local grillState = GrillStates[netIdNum] or GrillStates[netId]
    local maxDistance = Config.MeatSmokeDistance or 25.0

    if Config.EnableMeatSmoke == false
        or grillState ~= 'LIT'
        or not slotData
        or not slotData.isOccupied
        or not profile
        or not DoesEntityExist(propEntity)
        or #(playerCoords - grillCoords) > maxDistance then
        StopSlotSmoke(netIdNum, slotIndex)
        return
    end

    local smokeSlots = SlotSmokePtfx[netIdNum]
    if not smokeSlots then
        smokeSlots = {}
        SlotSmokePtfx[netIdNum] = smokeSlots
    end

    local existing = smokeSlots[slotIndex]
    if existing and existing.handle and existing.entity == propEntity and existing.status == status then
        return
    end
    if existing and existing.handle then
        StopParticleFxLooped(existing.handle, 0)
        smokeSlots[slotIndex] = nil
    end

    local dict = profile.dict or Config.SmokeParticleDict
    local name = profile.name or Config.SmokeParticleName
    if not dict or not name or not LoadPtfxDict(dict) then return end

    local offset = profile.offset or vector3(0.0, 0.0, 0.06)
    local rotation = profile.rotation or vector3(0.0, 0.0, 0.0)
    UseParticleFxAssetNextCall(dict)
    local handle = StartParticleFxLoopedOnEntity(
        name,
        propEntity,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        profile.scale or 0.08,
        false, false, false
    )
    if not handle or handle == 0 then return end

    local color = profile.color or { r = 0.85, g = 0.85, b = 0.85 }
    SetParticleFxLoopedAlpha(handle, profile.alpha or 0.35)
    SetParticleFxLoopedColour(handle, color.r or 0.85, color.g or 0.85, color.b or 0.85, false)
    smokeSlots[slotIndex] = {
        handle = handle,
        entity = propEntity,
        status = status
    }
end

local function DeleteAllSlotProps(netId)
    local netIdNum = tonumber(netId) or netId
    StopAllSlotSmoke(netIdNum)

    if SlotProps[netIdNum] then
        for slotIndex, propEntity in pairs(SlotProps[netIdNum]) do
            if DoesEntityExist(propEntity) then
                DeleteEntity(propEntity)
            end
        end
        SlotProps[netIdNum] = nil
    end
    if SlotProps[netId] then
        for slotIndex, propEntity in pairs(SlotProps[netId]) do
            if DoesEntityExist(propEntity) then
                DeleteEntity(propEntity)
            end
        end
        SlotProps[netId] = nil
    end
end

-- NOT: 'SetEntityColour' diye bir native YOK. Objelerde renk degisiminin
-- karsiligi tint index'tir; tint desteklemeyen proplarda sessizce yok sayilir.
local function ApplyBurntVisual(entity, isBurnt)
    if not DoesEntityExist(entity) then return end
    pcall(function()
        SetObjectTintIndex(entity, isBurnt and 4 or 0)
    end)
end

local function UpdateGrillSlotProps(netId)
    local netIdNum = tonumber(netId) or netId
    if not netIdNum or netIdNum == 0 then return end

    local slots = GrillSlots[netIdNum] or GrillSlots[netId] or GrillSlots[tostring(netId)]
    if not slots then
        DeleteAllSlotProps(netIdNum)
        return
    end

    local grillObj = nil
    if NetworkDoesNetworkIdExist(netIdNum) then
        grillObj = NetworkGetEntityFromNetworkId(netIdNum)
    end
    if not DoesEntityExist(grillObj) then
        DeleteAllSlotProps(netIdNum)
        return
    end

    local maxSlots = Config.MaxSlots or 6
    local offsets = Config.SlotOffsets or {}
    local playerCoords = GetEntityCoords(PlayerPedId())
    local grillCoords = GetEntityCoords(grillObj)

    -- Gerekli tum modelleri ONCEDEN yukle. Boylece asagidaki dongude Wait()
    -- olmuyor; yield sirasinda gelen ikinci sync event'i proplari
    -- tekrar olusturamiyor.
    local slotModels = {}
    for i = 1, maxSlots do
        local slotData = slots[i]
        if slotData and slotData.isOccupied then
            local recipe = GetRecipeById(slotData.item)
            local model = recipe and recipe.foodProp or `prop_cs_steak`

            if not EnsureModelLoaded(model) then
                model = `prop_cs_steak`
                EnsureModelLoaded(model)
            end

            if HasModelLoaded(model) then
                slotModels[i] = model
            end
        end
    end

    if not SlotProps[netIdNum] then
        SlotProps[netIdNum] = {}
    end

    for i = 1, maxSlots do
        local slotData = slots[i]
        local currentProp = SlotProps[netIdNum][i]

        if slotData and slotData.isOccupied then
            local model = slotModels[i]
            local slotOffset = offsets[i]
            local posX, posY, posZ = 0.0, 0.0, 0.40
            local rotX, rotY, rotZ = 0.0, 0.0, 0.0

            if type(slotOffset) == "vector3" then
                posX, posY, posZ = slotOffset.x, slotOffset.y, slotOffset.z
            elseif type(slotOffset) == "table" then
                if slotOffset.pos then
                    posX, posY, posZ = slotOffset.pos.x, slotOffset.pos.y, slotOffset.pos.z
                end
                if slotOffset.rot then
                    rotX, rotY, rotZ = slotOffset.rot.x, slotOffset.rot.y, slotOffset.rot.z
                end
            end

            if not DoesEntityExist(currentProp) then
                if model and HasModelLoaded(model) then
                    -- isNetwork = false: her istemci kendi gorsel kopyasini olusturur.
                    -- Networked yapilirsa mangal basindaki her oyuncu ayri bir
                    -- et prop'u spawn eder ve etler ust uste binerdi.
                    local propObj = CreateObject(model, grillCoords.x, grillCoords.y, grillCoords.z + 0.5, false, false, false)

                    if DoesEntityExist(propObj) then
                        SetEntityCollision(propObj, false, false)
                        FreezeEntityPosition(propObj, true)

                        AttachEntityToEntity(
                            propObj, grillObj, 0,
                            posX, posY, posZ,
                            rotX, rotY, rotZ,
                            false, false, false, false, 2, true
                        )

                        SlotProps[netIdNum][i] = propObj
                    end
                end
            else
                AttachEntityToEntity(
                    currentProp, grillObj, 0,
                    posX, posY, posZ,
                    rotX, rotY, rotZ,
                    false, false, false, false, 2, true
                )
            end

            -- Burnt Visual Effect
            local propEntity = SlotProps[netIdNum][i]
            ApplyBurntVisual(propEntity, slotData.status == 'BURNT')
            UpdateSlotSmoke(netIdNum, i, slotData, propEntity, grillObj, playerCoords, grillCoords)
        else
            StopSlotSmoke(netIdNum, i)
            if DoesEntityExist(currentProp) then
                DeleteEntity(currentProp)
                SlotProps[netIdNum][i] = nil
            end
        end
    end
end

-- ----------------------------------------------------
-- PTFX EFEKT VE DİNAMİK ISI ÖLÇEĞİ YÖNETİMİ
-- ----------------------------------------------------
local function SetGrillPtfxScale(netId, heat)
    local netIdNum = tonumber(netId) or netId
    if ActivePtfx[netIdNum] or ActivePtfx[netId] then
        local ptfx = ActivePtfx[netIdNum] or ActivePtfx[netId]
        local heatVal = heat or GrillHeat[netIdNum] or GrillHeat[netId] or 50
        local scale = 0.3 + ((heatVal / 100) * 0.7)
        if ptfx.fire then
            SetParticleFxLoopedScale(ptfx.fire, scale)
        end
        if ptfx.smoke then
            SetParticleFxLoopedScale(ptfx.smoke, scale * (Config.GrillSmokeScaleMultiplier or 0.45))
        end
    end
end

local function StartGrillPtfx(netId)
    local netIdNum = tonumber(netId) or netId
    if ActivePtfx[netIdNum] or ActivePtfx[netId] then return end
    if not NetworkDoesNetworkIdExist(netIdNum) then return end

    local entity = NetworkGetEntityFromNetworkId(netIdNum)
    if DoesEntityExist(entity) then
        local coords = GetEntityCoords(entity)
        if not LoadPtfxDict(Config.FireParticleDict) or not LoadPtfxDict(Config.SmokeParticleDict) then return end

        local heatVal = GrillHeat[netIdNum] or GrillHeat[netId] or 50
        local scale = 0.3 + ((heatVal / 100) * 0.7)

        UseParticleFxAssetNextCall(Config.FireParticleDict)
        local fireHandle = StartParticleFxLoopedAtCoord(
            Config.FireParticleName, 
            coords.x, coords.y, coords.z + 0.35, 
            0.0, 0.0, 0.0, 
            scale, false, false, false, false
        )

        local smokeScale = scale * (Config.GrillSmokeScaleMultiplier or 0.45)
        UseParticleFxAssetNextCall(Config.SmokeParticleDict)
        local smokeHandle = StartParticleFxLoopedAtCoord(
            Config.SmokeParticleName,
            coords.x, coords.y, coords.z + 0.4,
            0.0, 0.0, 0.0,
            smokeScale, false, false, false, false
        )
        if smokeHandle and smokeHandle ~= 0 then
            SetParticleFxLoopedAlpha(smokeHandle, Config.GrillSmokeAlpha or 0.50)
        end

        ActivePtfx[netIdNum] = { fire = fireHandle, smoke = smokeHandle }
        ActivePtfx[netId] = ActivePtfx[netIdNum]
    end
end

local function StopGrillPtfx(netId)
    local netIdNum = tonumber(netId) or netId
    local ptfx = ActivePtfx[netIdNum] or ActivePtfx[netId]
    if ptfx then
        if ptfx.fire then
            StopParticleFxLooped(ptfx.fire, 0)
        end
        if ptfx.smoke then
            StopParticleFxLooped(ptfx.smoke, 0)
        end
        ActivePtfx[netIdNum] = nil
        ActivePtfx[netId] = nil
    end
end

-- ----------------------------------------------------
-- XSOUND 3D SPATIAL SOUND MANAGEMENT
-- ----------------------------------------------------
local lastXSoundWarn = 0

local function IsXSoundEngine()
    return (Config.SoundEngine or 'nui') == 'xsound'
end

local function GetXSoundObject()
    if GetResourceState('xsound') == 'started' then
        return exports['xsound']
    elseif GetResourceState('xSound') == 'started' then
        return exports['xSound']
    end

    local now = GetGameTimer()
    if now - lastXSoundWarn > 15000 then
        lastXSoundWarn = now
        print("^1[mangal_script] UYARI: 'xsound' scripti sunucuda calismiyor veya yuklu degil! Ses oynatilamadi.^7")
    end
    return nil
end

local function GetSoundId(netId)
    local netIdNum = tonumber(netId) or netId
    return "mangal_sound_" .. tostring(netIdNum)
end

local function GetFormattedSoundUrl(soundFile)
    if not soundFile or soundFile == '' then return nil end
    local lower = string.lower(soundFile)
    if string.sub(lower, 1, 4) == 'http' or string.sub(lower, 1, 6) == 'nui://' then
        return soundFile
    end

    local resourceName = GetCurrentResourceName()
    return string.format("nui://%s/html/%s", resourceName, soundFile)
end

local function HasAnyMeatOnGrill(netId)
    local netIdNum = tonumber(netId) or netId
    local slots = GrillSlots[netIdNum] or GrillSlots[netId] or GrillSlots[tostring(netId)]
    if not slots then return false end

    for _, slot in pairs(slots) do
        if type(slot) == "table" and slot.isOccupied then
            return true
        end
    end
    return false
end

local function StopGrillSound(netId)
    -- NUI motorunda ses tek merkezi dongude yonetilir
    if not IsXSoundEngine() then return end

    local netIdNum = tonumber(netId) or netId
    if not netIdNum or netIdNum == 0 then return end

    local soundId = GetSoundId(netIdNum)
    if ActiveSounds[netIdNum] or ActiveSounds[netId] then
        ActiveSounds[netIdNum] = nil
        ActiveSounds[netId] = nil
    end

    local xSound = GetXSoundObject()
    if xSound then
        pcall(function()
            if xSound:soundExists(soundId) then
                xSound:Destroy(soundId)
            end
        end)
    end
end

local function UpdateGrillSound(netId)
    -- NUI motorunda ses tek merkezi dongude yonetilir
    if not IsXSoundEngine() then return end

    if Config.EnableSound == false then
        StopGrillSound(netId)
        return
    end

    local netIdNum = tonumber(netId) or netId
    if not netIdNum or netIdNum == 0 then return end

    local state = GrillStates[netIdNum] or GrillStates[netId]
    local hasMeat = HasAnyMeatOnGrill(netIdNum)

    -- Sound condition: Grill state must be 'LIT' AND have at least 1 meat on grill
    if state ~= 'LIT' or not hasMeat then
        StopGrillSound(netIdNum)
        return
    end

    local xSound = GetXSoundObject()
    if not xSound then return end

    local soundId = GetSoundId(netIdNum)
    local heat = GrillHeat[netIdNum] or GrillHeat[netId] or Config.DefaultHeat or 50
    local baseVolume = Config.SoundVolume or 0.4
    -- Dynamic volume scaling based on heat level (10% to 100%)
    local calculatedVolume = math.max(0.05, math.min(1.0, baseVolume * (heat / 100.0)))
    local maxDistance = Config.SoundDistance or 12.0
    local rawSoundFile = Config.SoundFile or 'sizzling.ogg'
    local soundUrl = GetFormattedSoundUrl(rawSoundFile)

    if not soundUrl then return end

    -- Find entity or position
    local coords = nil
    if NetworkDoesNetworkIdExist(netIdNum) then
        local entity = NetworkGetEntityFromNetworkId(netIdNum)
        if DoesEntityExist(entity) then
            coords = GetEntityCoords(entity)
        end
    end

    if not coords then return end

    local status, err = pcall(function()
        local soundExists = xSound:soundExists(soundId)
        if not soundExists then
            -- Play 3D positional sound in a loop
            xSound:PlayUrlPos(soundId, soundUrl, calculatedVolume, coords, true)
            xSound:Distance(soundId, maxDistance)
            ActiveSounds[netIdNum] = soundId
            ActiveSounds[netId] = soundId
        else
            -- Sound is already playing, update volume and position dynamically
            xSound:setVolume(soundId, calculatedVolume)
            xSound:Position(soundId, coords)
            xSound:Distance(soundId, maxDistance)
        end
    end)

    if not status then
        print("^1[mangal_script] xsound Hata:^7 " .. tostring(err))
    end
end

-- ----------------------------------------------------
-- NUI SES MOTORU (harici kaynak gerektirmez)
-- Kendi NUI sayfamizdaki <audio> ogesini kullanir. Mesafe ve isiya
-- gore ses seviyesi burada hesaplanip NUI'ye gonderilir.
-- ----------------------------------------------------
local nuiSoundPlaying = false
local nuiSoundVolume = -1.0

local function GetNuiSoundUrl()
    local file = Config.SoundFile
    if not file or file == '' then return nil end

    local lower = string.lower(file)
    if string.sub(lower, 1, 4) == 'http' then
        return file
    end

    -- NUI sayfasi html/ icinden servis edildigi icin dosya adi yeterli
    return file
end

local function StopNuiGrillSound()
    if not nuiSoundPlaying then return end
    nuiSoundPlaying = false
    nuiSoundVolume = -1.0

    -- fadeTime/maxVolume burada da gonderilir: NUI anlik kesmek yerine
    -- girisle ayni surede 0'a inip oyle durdurur.
    SendNUIMessage({
        action = 'grillSound',
        play = false,
        maxVolume = Config.SoundVolume or 0.4,
        fadeTime = Config.SoundFadeTime or 800
    })
end

CreateThread(function()
    while true do
        local sleep = 600

        if Config.EnableSound ~= false and not IsXSoundEngine() then
            local soundUrl = GetNuiSoundUrl()
            local maxDist = Config.SoundDistance or 12.0
            local pedCoords = GetEntityCoords(PlayerPedId())

            -- Ses cikaran en yakin mangali bul (yanan + uzerinde et olan)
            local bestDist, bestNetId = nil, nil

            for netId, state in pairs(GrillStates) do
                local netIdNum = tonumber(netId) or netId
                if state == 'LIT' and HasAnyMeatOnGrill(netIdNum) and NetworkDoesNetworkIdExist(netIdNum) then
                    local entity = NetworkGetEntityFromNetworkId(netIdNum)
                    if DoesEntityExist(entity) then
                        local dist = #(pedCoords - GetEntityCoords(entity))
                        if dist <= maxDist and (not bestDist or dist < bestDist) then
                            bestDist, bestNetId = dist, netIdNum
                        end
                    end
                end
            end

            if soundUrl and bestNetId then
                sleep = 250

                local baseVolume = Config.SoundVolume or 0.4
                local fullDist = math.min(Config.SoundFullVolumeDistance or 2.0, maxDist)
                local heat = GrillHeat[bestNetId] or Config.DefaultHeat or 50

                -- Mesafe egrisi: fullDist icinde tam ses, oradan maxDist'e
                -- dogrusal dusus. Yaklasirken ve uzaklasirken ayni egri.
                local distanceFactor
                if bestDist <= fullDist then
                    distanceFactor = 1.0
                else
                    distanceFactor = 1.0 - ((bestDist - fullDist) / math.max(0.1, maxDist - fullDist))
                end
                distanceFactor = math.max(0.0, math.min(1.0, distanceFactor))

                local heatFactor = math.max(0.35, math.min(1.0, heat / 100.0))
                local volume = baseVolume * distanceFactor * heatFactor
                volume = math.max(0.0, math.min(1.0, volume))

                -- Esik, ayarlanan ses araligina gore olceklenir. Sabit bir
                -- deger kullanilirsa dusuk SoundVolume'da ara kademeler atlanir.
                local epsilon = math.max(0.0005, baseVolume * 0.02)

                if not nuiSoundPlaying or math.abs(volume - nuiSoundVolume) > epsilon then
                    nuiSoundPlaying = true
                    nuiSoundVolume = volume
                    SendNUIMessage({
                        action = 'grillSound',
                        play = true,
                        volume = volume,
                        maxVolume = baseVolume,
                        fadeTime = Config.SoundFadeTime or 800,
                        src = soundUrl
                    })
                end
            else
                StopNuiGrillSound()
            end
        else
            StopNuiGrillSound()
        end

        Wait(sleep)
    end
end)



-- ----------------------------------------------------
-- STATE & SLOT NETWORK SYNC
-- ----------------------------------------------------
RegisterNetEvent('mangal:client:syncAllGrillStates')
AddEventHandler('mangal:client:syncAllGrillStates', function(states, heatMap, slotsMap, ownedMap)
    GrillStates = states or {}
    GrillHeat = heatMap or {}
    GrillSlots = slotsMap or {}
    OwnedGrills = {}

    for netId, isOwner in pairs(ownedMap or {}) do
        if isOwner then OwnedGrills[tonumber(netId) or netId] = true end
    end

    for netId, _ in pairs(GrillSlots) do
        UpdateGrillSlotProps(netId)
        UpdateGrillSound(netId)
    end
end)

RegisterNetEvent('mangal:client:syncGrillState')
AddEventHandler('mangal:client:syncGrillState', function(netId, state)
    if not netId then return end
    local netIdNum = tonumber(netId) or netId
    GrillStates[netIdNum] = state
    GrillStates[netId] = state

    if state == nil then
        OwnedGrills[netIdNum] = nil
        OwnedGrills[netId] = nil
    end

    if state == 'LIT' then
        StartGrillPtfx(netIdNum)
    else
        StopGrillPtfx(netIdNum)
    end
    UpdateGrillSound(netIdNum)
    UpdateGrillSlotProps(netIdNum)
    if RefreshNuiSlotMenu then RefreshNuiSlotMenu(netIdNum) end
end)

RegisterNetEvent('mangal:client:syncGrillHeat')
AddEventHandler('mangal:client:syncGrillHeat', function(netId, heat)
    if not netId then return end
    local netIdNum = tonumber(netId) or netId
    GrillHeat[netIdNum] = heat
    GrillHeat[netId] = heat
    SetGrillPtfxScale(netIdNum, heat)
    UpdateGrillSound(netIdNum)
    if RefreshNuiSlotMenu then RefreshNuiSlotMenu(netIdNum) end
end)

RegisterNetEvent('mangal:client:syncGrillSlots')
AddEventHandler('mangal:client:syncGrillSlots', function(netId, slots)
    if not netId then return end
    local netIdNum = tonumber(netId) or netId
    if not slots then
        GrillSlots[netIdNum] = nil
        GrillSlots[netId] = nil
        DeleteAllSlotProps(netIdNum)
        StopGrillSound(netIdNum)
        if activeSlotMenuNetId == netIdNum or activeSlotMenuNetId == netId then
            isSlotMenuOpen = false
            activeSlotMenuNetId = nil
            slotMenuSignature = nil
        end
    else
        GrillSlots[netIdNum] = slots
        GrillSlots[netId] = slots
        UpdateGrillSlotProps(netIdNum)
        UpdateGrillSound(netIdNum)

        -- Ozel NUI menusu acikken pisme yuzdelerini canli guncelle
        if RefreshNuiSlotMenu then
            RefreshNuiSlotMenu(netIdNum)
        end

        -- qb-menu / ox_lib yolu: menu acikken icerigi tazele
        if isSlotMenuOpen and (activeSlotMenuNetId == netIdNum or activeSlotMenuNetId == netId) then
            openSlotMenu(netIdNum, true)
        end
    end
end)

RegisterNetEvent('mangal:client:grillExtinguished')
AddEventHandler('mangal:client:grillExtinguished', function(netId)
    local netIdNum = tonumber(netId)
    if not netIdNum or not NetworkDoesNetworkIdExist(netIdNum) then return end

    local entity = NetworkGetEntityFromNetworkId(netIdNum)
    if not DoesEntityExist(entity) then return end

    if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(entity)) <= 8.0 then
        ShowNotification(Config.Lang['grill_extinguished'], 'error')
    end
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('mangal:server:requestAllStates')

    while true do
        Wait(1000)
        for netId, state in pairs(GrillStates) do
            local netIdNum = tonumber(netId) or netId
            if state == 'LIT' then
                if NetworkDoesNetworkIdExist(netIdNum) then
                    local entity = NetworkGetEntityFromNetworkId(netIdNum)
                    if DoesEntityExist(entity) then
                        if not ActivePtfx[netIdNum] and not ActivePtfx[netId] then
                            StartGrillPtfx(netIdNum)
                        else
                            SetGrillPtfxScale(netIdNum, GrillHeat[netIdNum])
                        end
                    else
                        StopGrillPtfx(netIdNum)
                    end
                end
            else
                StopGrillPtfx(netId)
            end

            UpdateGrillSound(netIdNum)
        end

        for netId, _ in pairs(GrillSlots) do
            UpdateGrillSlotProps(netId)
        end
    end
end)


-- ----------------------------------------------------
-- DİNAMİK MENÜLER: ET EKLEME VE SLOT KONTROLÜ
-- ----------------------------------------------------
local function CloseSlotMenuState()
    isSlotMenuOpen = false
    activeSlotMenuNetId = nil
    slotMenuSignature = nil
end

RegisterNetEvent('qb-menu:client:closeMenu', function()
    CloseSlotMenuState()
end)

-- qb-menu ESC ile kapatilinca bu event'i tetikler. Olmadan menu kapali
-- sayilmaz ve sonraki sync menuyu kendiliginden geri acardi.
AddEventHandler('qb-menu:client:menuClosed', function()
    CloseSlotMenuState()
end)

-- ----------------------------------------------------
-- OZEL NUI MENU KATMANI
-- ----------------------------------------------------
local function BuildSlotPayload(netIdNum)
    local slots = GrillSlots[netIdNum] or GrillSlots[tostring(netIdNum)] or {}
    local maxSlots = Config.MaxSlots or 6
    local payload = {}

    for i = 1, maxSlots do
        local slotData = slots[i]
        if slotData and slotData.isOccupied then
            local recipe = GetRecipeById(slotData.item)
            payload[i] = {
                index = i,
                occupied = true,
                label = recipe and recipe.label or 'Bilinmeyen Et',
                progress = math.floor(slotData.cookProgress or 0),
                status = slotData.status or 'RAW'
            }
        else
            payload[i] = { index = i, occupied = false }
        end
    end

    return payload
end

local function CloseNuiMenu(fromNui, keepGrillUse)
    pendingNuiMeatMenuRequest = nil
    if pendingGrillUseRequest then
        grillUseRequestId = grillUseRequestId + 1
        pendingGrillUseRequest = nil
    end
    if not keepGrillUse then
        ReleaseNuiGrillUse()
    end
    StopNuiGrillPose()
    if not isNuiMenuOpen then return end

    isNuiMenuOpen = false
    nuiMenuNetId = nil
    nuiMenuView = nil
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    -- NUI kendisi kapattiysa tekrar kapatma mesaji gondermeye gerek yok
    if not fromNui then
        SendNUIMessage({ action = 'closeMangalMenu' })
    end
end

local function OpenNuiSlotMenu(netIdNum)
    pendingNuiMeatMenuRequest = nil
    local state = GrillStates[netIdNum] or GrillStates[tostring(netIdNum)]
    isNuiMenuOpen = true
    nuiMenuNetId = netIdNum
    nuiMenuView = 'slots'

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({
        action = 'openSlotMenu',
        title = 'MANGAL KONTROLÜ',
        netId = netIdNum,
        state = state,
        heat = GrillHeat[netIdNum] or 0,
        isOwner = Config.OnlyOwnerCanRemove == false or OwnedGrills[netIdNum] == true,
        canAddMeat = state == 'LIT',
        burnThreshold = Config.BurnThreshold or 180,
        burnWarnPercent = (Config.BurnWarning and Config.BurnWarning.Enabled ~= false)
            and (Config.BurnWarning.StartPercent or 150) or nil,
        burnWarnSound = Config.BurnWarning and Config.BurnWarning.Sound ~= false,
        burnWarnText = Config.Lang['burn_warning_row'],
        slots = BuildSlotPayload(netIdNum)
    })
    StartNuiGrillPose(netIdNum)
end

local function OpenNuiMeatMenu(netIdNum, targetSlot)
    nuiMeatMenuRequestId = nuiMeatMenuRequestId + 1
    pendingNuiMeatMenuRequest = {
        id = nuiMeatMenuRequestId,
        netId = netIdNum,
        targetSlot = targetSlot
    }

    TriggerServerEvent(
        'mangal:server:requestRecipeAvailability',
        nuiMeatMenuRequestId,
        netIdNum,
        targetSlot
    )
end

ReleaseNuiGrillUse = function()
    if pendingGrillUseRequest then
        grillUseRequestId = grillUseRequestId + 1
    end
    pendingGrillUseRequest = nil

    if activeGrillUseNetId then
        TriggerServerEvent('mangal:server:releaseGrillUse', activeGrillUseNetId)
        activeGrillUseNetId = nil
    end
end

RequestNuiGrillUse = function(netId, view, targetSlot)
    local netIdNum = tonumber(netId) or netId
    if not netIdNum or netIdNum == 0 then return end

    if activeGrillUseNetId == netIdNum and isNuiMenuOpen then
        if view == 'slots' then
            OpenNuiSlotMenu(netIdNum)
        else
            OpenNuiMeatMenu(netIdNum, tonumber(targetSlot))
        end
        return
    end

    if activeGrillUseNetId then
        CloseNuiMenu(false)
    end
    if pendingGrillUseRequest then
        grillUseRequestId = grillUseRequestId + 1
        pendingGrillUseRequest = nil
    end

    grillUseRequestId = grillUseRequestId + 1
    pendingGrillUseRequest = {
        id = grillUseRequestId,
        netId = netIdNum,
        view = view,
        targetSlot = targetSlot
    }
    TriggerServerEvent('mangal:server:acquireGrillUse', grillUseRequestId, netIdNum)
end

RegisterNetEvent('mangal:client:grillUseResult')
AddEventHandler('mangal:client:grillUseResult', function(requestId, netId, granted)
    local responseNetId = tonumber(netId) or netId
    local pending = pendingGrillUseRequest

    if not pending or requestId ~= pending.id or pending.netId ~= responseNetId then
        if granted and activeGrillUseNetId ~= responseNetId
            and (not pending or pending.netId ~= responseNetId) then
            TriggerServerEvent('mangal:server:releaseGrillUse', responseNetId)
        end
        return
    end

    local view = pending.view
    local targetSlot = pending.targetSlot
    pendingGrillUseRequest = nil
    if not granted then return end

    activeGrillUseNetId = responseNetId
    if view == 'slots' then
        OpenNuiSlotMenu(responseNetId)
    else
        OpenNuiMeatMenu(responseNetId, tonumber(targetSlot))
    end
end)

RegisterNetEvent('mangal:client:grillUseReleased')
AddEventHandler('mangal:client:grillUseReleased', function(netId)
    local netIdNum = tonumber(netId) or netId
    if activeGrillUseNetId == netIdNum then
        activeGrillUseNetId = nil
    end
end)

RegisterNetEvent('mangal:client:grillUseLost')
AddEventHandler('mangal:client:grillUseLost', function(netId)
    local netIdNum = tonumber(netId) or netId
    local pending = pendingGrillUseRequest
    if activeGrillUseNetId ~= netIdNum and (not pending or pending.netId ~= netIdNum) then return end

    activeGrillUseNetId = nil
    pendingGrillUseRequest = nil
    CloseNuiMenu(true, true)
end)

CreateThread(function()
    while true do
        Wait(Config.GrillUseHeartbeatMs or 3000)
        if activeGrillUseNetId then
            TriggerServerEvent('mangal:server:heartbeatGrillUse', activeGrillUseNetId)
        end
    end
end)

RegisterNetEvent('mangal:client:recipeAvailability')
AddEventHandler('mangal:client:recipeAvailability', function(requestId, netIdNum, targetSlot, availability, seasoningAvailability)
    local pending = pendingNuiMeatMenuRequest
    if not pending or requestId ~= pending.id then return end
    pendingNuiMeatMenuRequest = nil

    local recipes = {}
    for _, recipe in ipairs(Config.Recipes) do
        recipes[#recipes + 1] = {
            id = recipe.id,
            label = recipe.label,
            cookTime = recipe.cookTime,
            hasRawItem = availability ~= nil and availability[recipe.id] == true
        }
    end

    local seasonings = {}
    for seasoningId, seasoningData in pairs(Config.Seasonings or {}) do
        seasonings[#seasonings + 1] = {
            id = seasoningId,
            label = seasoningData.label,
            hasItem = seasoningAvailability ~= nil and seasoningAvailability[seasoningId] == true
        }
    end

    isNuiMenuOpen = true
    nuiMenuNetId = netIdNum
    nuiMenuView = 'recipes'

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({
        action = 'openMeatMenu',
        title = 'ET SEÇİMİ',
        targetSlot = targetSlot,
        recipes = recipes,
        seasonings = seasonings
    })
    StartNuiGrillPose(netIdNum)
end)

-- NUI mouse odagindayken hareket serbest; mouse kamera/saldiri kontrollerine gitmez.
CreateThread(function()
    while true do
        if isNuiMenuOpen then
            Wait(0)

            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 1, true)   -- LOOK_LR
            DisableControlAction(0, 2, true)   -- LOOK_UD
            DisableControlAction(0, 24, true)  -- ATTACK
            DisableControlAction(0, 25, true)  -- AIM
            DisableControlAction(0, 68, true)  -- VEH_AIM
            DisableControlAction(0, 69, true)  -- VEH_ATTACK
            DisableControlAction(0, 70, true)  -- VEH_ATTACK2
            DisableControlAction(0, 91, true)  -- VEH_PASSENGER_AIM
            DisableControlAction(0, 92, true)  -- VEH_PASSENGER_ATTACK
            DisableControlAction(0, 106, true) -- VEH_MOUSE_CONTROL_OVERRIDE
            DisableControlAction(0, 114, true) -- VEH_FLY_ATTACK
            DisableControlAction(0, 140, true) -- MELEE_ATTACK_LIGHT
            DisableControlAction(0, 141, true) -- MELEE_ATTACK_HEAVY
            DisableControlAction(0, 142, true) -- MELEE_ATTACK_ALTERNATE
            DisableControlAction(0, 257, true) -- ATTACK2
            DisableControlAction(0, 263, true) -- MELEE_ATTACK1
            DisableControlAction(0, 264, true) -- MELEE_ATTACK2
            DisableControlAction(0, 331, true) -- VEH_FLY_ATTACK2

            -- SetNuiFocusKeepInput(true) mouse tiklamasini oyuna da gonderdigi icin
            -- DisableControlAction bazen yetmiyor; SetInputExclusive kontrolu tamamen kilitler.
            SetInputExclusive(0, 24)  -- ATTACK
            SetInputExclusive(0, 25)  -- AIM
            SetInputExclusive(0, 140) -- MELEE_ATTACK_LIGHT
            SetInputExclusive(0, 141) -- MELEE_ATTACK_HEAVY
            SetInputExclusive(0, 142) -- MELEE_ATTACK_ALTERNATE
            SetInputExclusive(0, 257) -- ATTACK2
            SetInputExclusive(0, 263) -- MELEE_ATTACK1
            SetInputExclusive(0, 264) -- MELEE_ATTACK2
        else
            Wait(250)
        end
    end
end)

-- Menu acikken pisme yuzdelerini canli guncelle (menu yeniden cizilmez)
RefreshNuiSlotMenu = function(netIdNum)
    if not isNuiMenuOpen or nuiMenuView ~= 'slots' then return end
    if nuiMenuNetId ~= netIdNum then return end

    SendNUIMessage({
        action = 'updateSlotMenu',
        netId = netIdNum,
        state = GrillStates[netIdNum] or GrillStates[tostring(netIdNum)],
        heat = GrillHeat[netIdNum] or 0,
        isOwner = Config.OnlyOwnerCanRemove == false or OwnedGrills[netIdNum] == true,
        canAddMeat = (GrillStates[netIdNum] or GrillStates[tostring(netIdNum)]) == 'LIT',
        burnThreshold = Config.BurnThreshold or 180,
        burnWarnPercent = (Config.BurnWarning and Config.BurnWarning.Enabled ~= false)
            and (Config.BurnWarning.StartPercent or 150) or nil,
        burnWarnSound = Config.BurnWarning and Config.BurnWarning.Sound ~= false,
        burnWarnText = Config.Lang['burn_warning_row'],
        slots = BuildSlotPayload(netIdNum)
    })
end

-- Acik NUI menusu HUD'in gorunurluk mesafesine bagli olmamali.
-- Ozellikle yokusta, HUD icin uygun olan kisa mesafe oyuncu-mangal arasindaki
-- 3D mesafeyi asabilir ve menunun hemen kapanmasina neden olabilir.
CreateThread(function()
    while true do
        Wait(250)

        local menuDistance = Config.NuiMenuDistance
            or Config.GrillInteractDistance
            or Config.InteractDistance
            or 2.5
        if isNuiMenuOpen and nuiMenuNetId then
            local inRange = false

            if nuiMenuNetId and NetworkDoesNetworkIdExist(nuiMenuNetId) then
                local entity = NetworkGetEntityFromNetworkId(nuiMenuNetId)
                if DoesEntityExist(entity) then
                    local pedCoords = GetEntityCoords(PlayerPedId())
                    inRange = #(pedCoords - GetEntityCoords(entity)) <= menuDistance
                end
            end

            if not inRange then CloseNuiMenu(false) end
        end
    end
end)

local function openAddMeatMenu(netId, targetSlot)
    local netIdNum = tonumber(netId) or netId
    if not netIdNum or netIdNum == 0 then return end

    CloseSlotMenuState()

    if Config.UseNuiMenus ~= false then
        RequestNuiGrillUse(netIdNum, 'meat', tonumber(targetSlot))
        return
    end

    local menuItems = {}
    for _, recipe in ipairs(Config.Recipes) do
        table.insert(menuItems, {
            header = recipe.label,
            title = recipe.label,
            txt = recipe.cookTime .. " saniye pişirme süresi",
            description = recipe.cookTime .. " saniye pişirme süresi",
            icon = "fas fa-drumstick-bite",
            params = {
                event = "mangal:client:selectMeatToAdd",
                args = { netId = netIdNum, recipeId = recipe.id, targetSlot = targetSlot }
            },
            onSelect = function()
                CloseSlotMenuState()
                TriggerServerEvent('mangal:server:requestAddMeat', netIdNum, recipe.id, targetSlot)
            end
        })
    end

    if GetResourceState('qb-menu') == 'started' then
        local qbMenu = {
            {
                header = "Izgara - Et Seçimi",
                isMenuHeader = true,
            }
        }
        for _, item in ipairs(menuItems) do
            table.insert(qbMenu, item)
        end
        exports['qb-menu']:openMenu(qbMenu)
    elseif GetResourceState('ox_lib') == 'started' then
        local oxOptions = {}
        for _, item in ipairs(menuItems) do
            table.insert(oxOptions, {
                title = item.title,
                description = item.description,
                icon = item.icon,
                onSelect = item.onSelect
            })
        end
        exports.ox_lib:registerContext({
            id = 'mangal_add_meat_menu',
            title = 'Izgara - Et Seçimi',
            options = oxOptions
        })
        exports.ox_lib:showContext('mangal_add_meat_menu')
    else
        TriggerServerEvent('mangal:server:requestAddMeat', netIdNum, Config.Recipes[1].id, targetSlot)
    end
end

-- isRefresh = true: menu zaten acikken icerigi tazelemek icin cagrilir.
-- Icerik degismediyse tekrar cizilmez (imlec/kaydirma sifirlanmasin diye).
openSlotMenu = function(netId, isRefresh)
    local netIdNum = tonumber(netId) or netId
    if not netIdNum or netIdNum == 0 then return end

    -- Ozel NUI menusu: canli guncelleme RefreshNuiSlotMenu ile yapilir,
    -- bu yol yalnizca menuyu ilk acarken kullanilir.
    if Config.UseNuiMenus ~= false then
        if not isRefresh then
            RequestNuiGrillUse(netIdNum, 'slots')
        end
        return
    end

    local slots = GrillSlots[netIdNum] or GrillSlots[netId] or {}
    local maxSlots = Config.MaxSlots or 6
    local menuItems = {}
    local signatureParts = {}

    for i = 1, maxSlots do
        local slotData = slots[i]
        if slotData and slotData.isOccupied then
            local recipe = GetRecipeById(slotData.item)
            local statusLabel = "ÇİĞ"
            if slotData.status == 'COOKED' then
                statusLabel = "PİŞMİŞ"
            elseif slotData.status == 'BURNT' then
                statusLabel = "YANMIŞ"
            end

            local text = string.format("Bölme %d: %s [%d%%] (%s)", i, recipe.label, math.floor(slotData.cookProgress or 0), statusLabel)
            signatureParts[#signatureParts + 1] = text
            local isBurnt = slotData.status == 'BURNT'

            table.insert(menuItems, {
                header = text,
                title = text,
                txt = "Eti ızgaradan toplamak için tıklayın",
                description = "Eti ızgaradan toplamak için tıklayın",
                icon = "fas fa-utensils",
                params = {
                    event = "mangal:client:selectSlotToPick",
                    args = { netId = netIdNum, slotIndex = i, status = slotData.status }
                },
                onSelect = function()
                    if not isBurnt then
                        CloseSlotMenuState()
                    end
                    TriggerServerEvent('mangal:server:requestPickMeat', netIdNum, i, isBurnt)
                end
            })
        else
            local text = string.format("Bölme %d: [BOŞ]", i)
            signatureParts[#signatureParts + 1] = text

            table.insert(menuItems, {
                header = text,
                title = text,
                txt = "Et eklemek için tıklayın",
                description = "Et eklemek için tıklayın",
                icon = "fas fa-plus",
                params = {
                    event = "mangal:client:selectSlotToAdd",
                    args = { netId = netIdNum, slotIndex = i }
                },
                onSelect = function()
                    openAddMeatMenu(netIdNum, i)
                end
            })
        end
    end

    local signature = table.concat(signatureParts, '|')
    if isRefresh and signature == slotMenuSignature then return end

    slotMenuSignature = signature
    activeSlotMenuNetId = netIdNum
    isSlotMenuOpen = true

    if GetResourceState('qb-menu') == 'started' then
        local qbMenu = {
            {
                header = "Izgara Bölmeleri ve Et Toplama",
                isMenuHeader = true,
            }
        }
        for _, item in ipairs(menuItems) do
            table.insert(qbMenu, item)
        end
        exports['qb-menu']:openMenu(qbMenu)
    elseif GetResourceState('ox_lib') == 'started' then
        local oxOptions = {}
        for _, item in ipairs(menuItems) do
            table.insert(oxOptions, {
                title = item.title,
                description = item.description,
                icon = item.icon,
                onSelect = item.onSelect
            })
        end
        exports.ox_lib:registerContext({
            id = 'mangal_slot_control_menu',
            title = 'Izgara Bölmeleri ve Et Toplama',
            options = oxOptions,
            onClose = function()
                CloseSlotMenuState()
            end
        })
        exports.ox_lib:showContext('mangal_slot_control_menu')
    end
end

-- Slot Menüsü güncellemesi sadece sunucudan veri geldiğinde (syncGrillSlots) tetiklenir.

-- ----------------------------------------------------
-- NUI CALLBACK'LERI (Ozel Menu)
-- ----------------------------------------------------
RegisterNUICallback('grillAction', function(data, cb)
    cb('ok')

    local netIdNum = nuiMenuNetId
    local action = data and data.action
    if not netIdNum or not action then return end

    local state = GrillStates[netIdNum] or GrillStates[tostring(netIdNum)]
    if action == 'addCoal' and state == 'EMPTY' then
        TriggerServerEvent('mangal:server:requestAddCoal', netIdNum)
    elseif action == 'light' and state == 'HAS_COAL' then
        TriggerServerEvent('mangal:server:requestLightGrill', netIdNum)
    elseif action == 'fan' and state == 'LIT' then
        TriggerServerEvent('mangal:server:requestFanGrill', netIdNum)
    elseif action == 'remove' and (Config.OnlyOwnerCanRemove == false or OwnedGrills[netIdNum] == true) then
        CloseNuiMenu(false, true)
        local removalStarted = false
        if NetworkDoesNetworkIdExist(netIdNum) then
            local entity = NetworkGetEntityFromNetworkId(netIdNum)
            if DoesEntityExist(entity) then
                removalStarted = true
                TriggerEvent('mangal:client:startRemovingGrill', entity)
            end
        end
        if not removalStarted then
            ReleaseNuiGrillUse()
        end
    end
end)

RegisterNUICallback('slotSelected', function(data, cb)
    cb('ok')

    local netIdNum = nuiMenuNetId
    local slotIndex = tonumber(data and data.slotIndex)
    if not netIdNum or not slotIndex then return end

    if data.occupied then
        local keepMenuOpen = data.status == 'BURNT'
        if not keepMenuOpen then
            CloseNuiMenu(false, true)
        end
        TriggerServerEvent('mangal:server:requestPickMeat', netIdNum, slotIndex, keepMenuOpen)
    else
        RequestNuiGrillUse(netIdNum, 'meat', slotIndex)
    end
end)

RegisterNUICallback('recipeSelected', function(data, cb)
    cb('ok')

    local netIdNum = nuiMenuNetId
    if not netIdNum or not data or not data.recipeId then return end

    local targetSlot = tonumber(data.targetSlot)
    TriggerServerEvent('mangal:server:requestAddMeat', netIdNum, data.recipeId, targetSlot, data.seasoningId)
    OpenNuiSlotMenu(netIdNum)
end)

RegisterNUICallback('backToSlots', function(_, cb)
    cb('ok')
    -- NUI onbellekten cizmis olabilir; guncel veriyle tekrar gonder
    if nuiMenuNetId then
        OpenNuiSlotMenu(nuiMenuNetId)
    end
end)

RegisterNUICallback('menuClosed', function(_, cb)
    cb('ok')
    CloseNuiMenu(true)
end)

-- Menu Event Handlers
AddEventHandler('mangal:client:selectMeatToAdd', function(data)
    if data and data.netId and data.recipeId then
        TriggerServerEvent('mangal:server:requestAddMeat', data.netId, data.recipeId, data.targetSlot)
    end
end)

AddEventHandler('mangal:client:selectSlotToPick', function(data)
    if data and data.netId and data.slotIndex then
        -- qb-menu tiklamada menuyu kapatir ama bizim durumumuzu sifirlamaz;
        -- sifirlanmazsa sonraki sync menuyu tekrar acar.
        local keepMenuOpen = data.status == 'BURNT'
        if not keepMenuOpen then
            CloseSlotMenuState()
        end
        TriggerServerEvent('mangal:server:requestPickMeat', data.netId, data.slotIndex, keepMenuOpen)
    end
end)

AddEventHandler('mangal:client:selectSlotToAdd', function(data)
    if data and data.netId and data.slotIndex then
        openAddMeatMenu(data.netId, data.slotIndex)
    end
end)

-- ----------------------------------------------------
-- TARGET SYSTEM INTEGRATION (STALE REFERENCE SAFE)
-- ----------------------------------------------------
local function UnregisterTargetSystem()
    local models = {
        'prop_bbq_5',
        'prop_bbq_02',
        `prop_bbq_5`,
        `prop_bbq_02`,
        Config.GrillModel
    }

    local labels = {
        Config.Lang['target_start'],
        Config.Lang['target_add_coal'],
        Config.Lang['target_light_grill'],
        Config.Lang['target_fan'],
        Config.Lang['target_cook'],
        Config.Lang['target_slots'],
        Config.Lang['target_remove'],
        "Mangala Basla",
        "Komur Ekle",
        "Mangali Yak",
        "Et Pisir",
        "Et Ekle",
        "Izgarayi Kontrol Et / Et Topla",
        "Atesi Yelpazele",
        "Mangali Topla"
    }

    if GetResourceState('qb-target') == 'started' then
        pcall(function()
            exports['qb-target']:RemoveTargetModel(models, labels)
        end)
    end

    if GetResourceState('ox_target') == 'started' then
        pcall(function()
            exports.ox_target:removeModel(models, {
                'mangal_add_coal',
                'mangal_light_grill',
                'mangal_fan',
                'mangal_add_meat',
                'mangal_slot_menu',
                'mangal_remove',
                'mangal_start'
            })
        end)
    end
end

local function RegisterTargetSystem()
    UnregisterTargetSystem()
    Wait(50)

    local models = {
        Config.GrillModel,
        `prop_bbq_5`,
        `prop_bbq_02`,
        'prop_bbq_5',
        'prop_bbq_02'
    }

    -- QB-TARGET
    if (Config.TargetSystem == 'qb-target' or Config.TargetSystem == 'auto') and (GetResourceState('qb-target') == 'started' or exports['qb-target']) then
        pcall(function()
            exports['qb-target']:AddTargetModel(models, {
                options = {
                    {
                        type = "client",
                        event = "mangal:client:targetStart",
                        icon = "fas fa-fire",
                        label = Config.Lang['target_start'],
                        canInteract = function(entity)
                            if not entity or not DoesEntityExist(entity) then return false end
                            local netId = NetworkGetNetworkIdFromEntity(entity)
                            return not isCooking and GrillStates[netId] ~= nil
                        end
                    }
                },
                distance = Config.InteractDistance or 2.5
            })
        end)
    end

    -- OX_TARGET
    if (Config.TargetSystem == 'ox_target' or Config.TargetSystem == 'auto') and GetResourceState('ox_target') == 'started' then
        pcall(function()
            exports.ox_target:addModel(models, {
                {
                    name = 'mangal_start',
                    icon = 'fas fa-fire',
                    label = Config.Lang['target_start'],
                    canInteract = function(entity)
                        if not entity or not DoesEntityExist(entity) then return false end
                        local netId = NetworkGetNetworkIdFromEntity(entity)
                        return not isCooking and GrillStates[netId] ~= nil
                    end,
                    onSelect = function(data)
                        local netId = NetworkGetNetworkIdFromEntity(data.entity)
                        openSlotMenu(netId)
                    end
                }
            })
        end)
    end
end

CreateThread(function()
    Wait(500)
    RegisterTargetSystem()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == 'qb-core' and Config.Framework == 'qbcore' then
        ClientBridge.RefreshCore()
    end

    if resourceName == 'qb-target' or resourceName == 'ox_target' then
        CreateThread(function()
            Wait(250)
            RegisterTargetSystem()
        end)
    end
end)

-- Target Event Handlers
AddEventHandler('mangal:client:targetStart', function(data)
    local entity = (type(data) == "table" and data.entity) or data
    if DoesEntityExist(entity) then
        local netId = NetworkGetNetworkIdFromEntity(entity)
        openSlotMenu(netId)
    end
end)

FacePedToGrill = function(grillObj)
    if not DoesEntityExist(grillObj) then return end
    local ped = PlayerPedId()
    local grillHeading = GetEntityHeading(grillObj)
    local frontCoords = GetOffsetFromEntityInWorldCoords(grillObj, 0.0, -0.75, 0.0)

    SetEntityCoords(ped, frontCoords.x, frontCoords.y, frontCoords.z, false, false, false, true)
    SetEntityHeading(ped, grillHeading)
end

StartNuiGrillHandProp = function(ped, token)
    if DoesEntityExist(nuiGrillHandProp) then return end

    local propModel = Config.HandPropModel or `prop_fish_slice_01`
    if not EnsureModelLoaded(propModel) then return end
    if token and (not nuiGrillPoseActive or token ~= nuiGrillPoseToken) then return end

    local pedCoords = GetEntityCoords(ped)
    local propObj = CreateObject(propModel, pedCoords.x, pedCoords.y, pedCoords.z, false, false, false)
    if DoesEntityExist(propObj) then
        AttachEntityToEntity(
            propObj, ped, GetPedBoneIndex(ped, 57005),
            0.1, 0.0, -0.02,
            -80.0, 90.0, 80.0,
            true, true, false, true, 1, true
        )
        nuiGrillHandProp = propObj
    end
    SetModelAsNoLongerNeeded(propModel)
end

StopNuiGrillHandProp = function()
    if DoesEntityExist(nuiGrillHandProp) then
        DeleteEntity(nuiGrillHandProp)
    end
    nuiGrillHandProp = nil
end

StartNuiGrillPose = function(netIdNum)
    local poseNetId = tonumber(netIdNum) or netIdNum
    if not poseNetId or poseNetId == 0 then return end

    local grillObj = nil
    if NetworkDoesNetworkIdExist(poseNetId) then
        grillObj = NetworkGetEntityFromNetworkId(poseNetId)
    end
    if not DoesEntityExist(grillObj) then return end

    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end

    if nuiGrillPoseActive and nuiGrillPoseNetId == poseNetId then
        FreezeEntityPosition(ped, true)
        return
    end

    if nuiGrillPoseActive then
        StopNuiGrillPose()
    end

    FacePedToGrill(grillObj)
    FreezeEntityPosition(ped, true)
    nuiGrillPoseActive = true
    nuiGrillPoseNetId = poseNetId
    nuiGrillPoseAnimReady = false
    nuiGrillPoseToken = nuiGrillPoseToken + 1
    local token = nuiGrillPoseToken

    local animDict = 'amb@prop_human_bbq@male@idle_b'
    local animName = 'idle_e'
    if not LoadAnimDict(animDict) then
        if nuiGrillPoseToken == token then StopNuiGrillPose() end
        return
    end

    if nuiGrillPoseToken ~= token or not nuiGrillPoseActive then return end
    nuiGrillPoseAnimReady = true
    StartNuiGrillHandProp(ped, token)
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
end

StopNuiGrillPose = function()
    nuiGrillPoseToken = nuiGrillPoseToken + 1
    StopNuiGrillHandProp()
    if nuiGrillPoseActive then
        local ped = PlayerPedId()
        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, false)
    end
    nuiGrillPoseActive = false
    nuiGrillPoseNetId = nil
    nuiGrillPoseAnimReady = false
end

ResumeNuiGrillPose = function(netId)
    if not isNuiMenuOpen then return end

    local menuNetId = tonumber(nuiMenuNetId) or nuiMenuNetId
    local actionNetId = tonumber(netId) or netId
    if not menuNetId or menuNetId ~= actionNetId then return end

    StartNuiGrillPose(actionNetId)
end

CreateThread(function()
    while true do
        Wait(250)
        if nuiGrillPoseActive then
            local ped = PlayerPedId()
            if not isNuiMenuOpen or IsEntityDead(ped) then
                if isNuiMenuOpen then
                    CloseNuiMenu(false)
                else
                    StopNuiGrillPose()
                end
            elseif not nuiGrillPoseNetId or not NetworkDoesNetworkIdExist(nuiGrillPoseNetId) then
                CloseNuiMenu(false)
            else
                local grillObj = NetworkGetEntityFromNetworkId(nuiGrillPoseNetId)
                if not DoesEntityExist(grillObj) then
                    CloseNuiMenu(false)
                else
                    FreezeEntityPosition(ped, true)
                    if nuiGrillPoseAnimReady and not DoesEntityExist(nuiGrillHandProp) then
                        StartNuiGrillHandProp(ped, nuiGrillPoseToken)
                    end
                    if nuiGrillPoseAnimReady
                        and not IsEntityPlayingAnim(ped, 'amb@prop_human_bbq@male@idle_b', 'idle_e', 3) then
                        TaskPlayAnim(ped, 'amb@prop_human_bbq@male@idle_b', 'idle_e', 8.0, -8.0, -1, 1, 0, false, false, false)
                    end
                end
            end
        end
    end
end)

-- ----------------------------------------------------
-- KÖMÜR EKLEME & MANGAL YAKMA AKSİYONLARI
-- ----------------------------------------------------
RegisterNetEvent('mangal:client:startAddCoal')
AddEventHandler('mangal:client:startAddCoal', function(netId)
    local ped = PlayerPedId()
    
    local grillObj = nil
    if netId and NetworkDoesNetworkIdExist(netId) then
        grillObj = NetworkGetEntityFromNetworkId(netId)
    end
    if not DoesEntityExist(grillObj) then
        TriggerServerEvent('mangal:server:cancelAction', 'addCoal', netId)
        return
    end

    StopNuiGrillPose()
    if DoesEntityExist(grillObj) then
        FacePedToGrill(grillObj)
    end

    local animDict = "mini@repair"
    local animName = "fixing_a_ped"

    if LoadAnimDict(animDict) then
        TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, Config.AddCoalTime, 1, 0, false, false, false)
    end

    ClientBridge.Progressbar("mangal_add_coal", Config.Lang['adding_coal'], Config.AddCoalTime, nil, function() -- Done
        ClearPedTasks(ped)
        ResumeNuiGrillPose(netId)
        if not IsEntityDead(ped) then
            TriggerServerEvent('mangal:server:finishAddCoal', netId)
        else
            TriggerServerEvent('mangal:server:cancelAction', 'addCoal', netId)
        end
    end, function() -- Cancel
        ClearPedTasks(ped)
        ResumeNuiGrillPose(netId)
        TriggerServerEvent('mangal:server:cancelAction', 'addCoal', netId)
        ShowNotification(Config.Lang['action_cancelled'])
    end)
end)

RegisterNetEvent('mangal:client:startLightGrill')
AddEventHandler('mangal:client:startLightGrill', function(netId)
    local ped = PlayerPedId()

    local grillObj = nil
    if netId and NetworkDoesNetworkIdExist(netId) then
        grillObj = NetworkGetEntityFromNetworkId(netId)
    end
    if not DoesEntityExist(grillObj) then
        TriggerServerEvent('mangal:server:cancelAction', 'lightGrill', netId)
        return
    end

    StopNuiGrillPose()
    if DoesEntityExist(grillObj) then
        FacePedToGrill(grillObj)
    end

    local animDict = "mini@repair"
    local animName = "fixing_a_ped"

    if LoadAnimDict(animDict) then
        TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, Config.LightGrillTime, 1, 0, false, false, false)
    end

    ClientBridge.Progressbar("mangal_light", Config.Lang['lighting_grill'], Config.LightGrillTime, nil, function() -- Done
        ClearPedTasks(ped)
        ResumeNuiGrillPose(netId)
        if not IsEntityDead(ped) then
            TriggerServerEvent('mangal:server:finishLightGrill', netId)
        else
            TriggerServerEvent('mangal:server:cancelAction', 'lightGrill', netId)
        end
    end, function() -- Cancel
        ClearPedTasks(ped)
        ResumeNuiGrillPose(netId)
        TriggerServerEvent('mangal:server:cancelAction', 'lightGrill', netId)
        ShowNotification(Config.Lang['action_cancelled'])
    end)
end)

-- ----------------------------------------------------
-- ATEŞİ YELPAZELEME & MINIGAME
-- ----------------------------------------------------
RegisterNetEvent('mangal:client:startFanning')
AddEventHandler('mangal:client:startFanning', function(netId)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    local grillObj = nil
    if netId and NetworkDoesNetworkIdExist(netId) then
        grillObj = NetworkGetEntityFromNetworkId(netId)
    end
    if not DoesEntityExist(grillObj) then
        TriggerServerEvent('mangal:server:cancelAction', 'fanGrill', netId)
        return
    end

    StopNuiGrillPose()
    if DoesEntityExist(grillObj) then
        FacePedToGrill(grillObj)
    end

    -- Fan prop/anim asset'leri yuklenirken ped serbest kalmamali.
    -- Aksi halde ilk Wait() araliginda oyuncu hareket eder ve pose
    -- yeniden baslatilinca eski konumuna geri cekilir.
    FreezeEntityPosition(ped, true)

    local fanProp = nil
    local propModel = Config.FanPropModel or `prop_anim_newspaper`
    if EnsureModelLoaded(propModel) then
        fanProp = CreateObject(propModel, pedCoords.x, pedCoords.y, pedCoords.z, false, false, false)
        AttachEntityToEntity(
            fanProp, ped, GetPedBoneIndex(ped, 57005), 
            0.1, 0.0, -0.02, 
            0.0, 90.0, 90.0, 
            true, true, false, true, 1, true
        )
    end

    local animDict = "amb@world_human_fan@male@idle_a"
    local animName = "idle_a"
    if not LoadAnimDict(animDict) then
        animDict = "mini@repair"
        animName = "fixing_a_ped"
        LoadAnimDict(animDict)
    end
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)

    local isSuccess = ClientBridge.FanMinigame()

    ClearPedTasks(ped)
    if DoesEntityExist(fanProp) then
        DeleteEntity(fanProp)
    end
    if propModel then SetModelAsNoLongerNeeded(propModel) end

    TriggerServerEvent('mangal:server:finishFanning', netId, isSuccess)
    ResumeNuiGrillPose(netId)
    if not nuiGrillPoseActive then
        FreezeEntityPosition(ped, false)
    end
end)

-- ----------------------------------------------------
-- MANGAL KURMA & TOPLAMA (STRICT NETWORK REGISTRATION)
-- ----------------------------------------------------
RegisterNetEvent('mangal:client:placementRejected')
AddEventHandler('mangal:client:placementRejected', function()
    if DoesEntityExist(pendingPlacementEntity) then
        DeleteEntity(pendingPlacementEntity)
    end
    pendingPlacementEntity = nil
end)

RegisterNetEvent('mangal:client:placementApproved')
AddEventHandler('mangal:client:placementApproved', function(netId)
    pendingPlacementEntity = nil

    local netIdNum = tonumber(netId)
    if not netIdNum then return end

    OwnedGrills[netIdNum] = true
end)

RegisterNetEvent('mangal:client:deleteGrillEntity')
AddEventHandler('mangal:client:deleteGrillEntity', function(netId)
    local netIdNum = tonumber(netId)
    if not netIdNum or not NetworkDoesNetworkIdExist(netIdNum) then return end
    local entity = NetworkGetEntityFromNetworkId(netIdNum)
    if not DoesEntityExist(entity) then return end

    NetworkRequestControlOfEntity(entity)
    local timeout = 0
    while not NetworkHasControlOfEntity(entity) and timeout < 20 do
        Wait(25)
        NetworkRequestControlOfEntity(entity)
        timeout = timeout + 1
    end
    if NetworkHasControlOfEntity(entity) then DeleteEntity(entity) end
end)

RegisterNetEvent('mangal:client:startPlacingGrill')
AddEventHandler('mangal:client:startPlacingGrill', function()
    local ped = PlayerPedId()
    local modelHash = GetValidGrillModel()

    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)
    local heading = GetEntityHeading(ped)

    local closestObject = GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.0, modelHash, false, false, false)
    if DoesEntityExist(closestObject) then
        ShowNotification(Config.Lang['grill_already_exists'])
        SetModelAsNoLongerNeeded(modelHash)
        TriggerServerEvent('mangal:server:cancelPlacement')
        return
    end

    local animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
    local animName = "machinic_loop_mechandplayer"
    if LoadAnimDict(animDict) then
        TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, 2000, 1, 0, false, false, false)
    end
    Wait(1800)

    local grillObj = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, true)
    if not DoesEntityExist(grillObj) then
        ClearPedTasks(ped)
        TriggerServerEvent('mangal:server:cancelPlacement')
        return
    end
    pendingPlacementEntity = grillObj
    SetEntityHeading(grillObj, heading)
    PlaceObjectOnGroundProperly(grillObj)
    FreezeEntityPosition(grillObj, true)
    SetEntityAsMissionEntity(grillObj, true, true)

    -- NETWORK HANDSHAKE GUARANTEE
    local timeout = 0
    while not NetworkGetEntityIsNetworked(grillObj) and timeout < 25 do
        NetworkRegisterEntityAsNetworked(grillObj)
        Wait(40)
        timeout = timeout + 1
    end

    local netId = NetworkGetNetworkIdFromEntity(grillObj)
    if netId and netId ~= 0 then
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetNetworkIdCanMigrate(netId, true)
    end

    SetModelAsNoLongerNeeded(modelHash)
    ClearPedTasks(ped)

    TriggerServerEvent('mangal:server:createGrill', netId)
    local submittedEntity = grillObj
    CreateThread(function()
        Wait((Config.PlacementRequestTimeout or 15000) + 1000)
        if pendingPlacementEntity == submittedEntity then
            if DoesEntityExist(submittedEntity) then DeleteEntity(submittedEntity) end
            pendingPlacementEntity = nil
        end
    end)
end)

RegisterCommand(Config.BuildCommand, function()
    TriggerServerEvent('mangal:server:requestPlaceGrill')
end, false)

RegisterNetEvent('mangal:client:startRemovingGrill')
AddEventHandler('mangal:client:startRemovingGrill', function(targetObject)
    local ped = PlayerPedId()
    local objectToDelete = targetObject

    if not objectToDelete or not DoesEntityExist(objectToDelete) then
        local coords = GetEntityCoords(ped)
        local modelHash = GetValidGrillModel()
        objectToDelete = GetClosestObjectOfType(coords.x, coords.y, coords.z, 3.0, modelHash, false, false, false)
        if not DoesEntityExist(objectToDelete) then
            objectToDelete = GetClosestObjectOfType(coords.x, coords.y, coords.z, 3.0, `prop_bbq_5`, false, false, false)
        end
    end

    if DoesEntityExist(objectToDelete) then
        FacePedToGrill(objectToDelete)
        local netId = NetworkGetNetworkIdFromEntity(objectToDelete)

        local animDict = "mini@repair"
        local animName = "fixing_a_ped"
        if LoadAnimDict(animDict) then
            TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, 1800, 1, 0, false, false, false)
        end
        Wait(1800)

        ClearPedTasks(ped)
        TriggerServerEvent('mangal:server:removeGrill', netId)
    else
        ShowNotification(Config.Lang['no_grill_nearby'])
        ReleaseNuiGrillUse()
    end
end)

RegisterCommand(Config.RemoveCommand, function()
    TriggerEvent('mangal:client:startRemovingGrill', nil)
end, false)

-- ----------------------------------------------------
-- YEMEK YEME ANIMASYONU
-- ----------------------------------------------------
RegisterNetEvent('mangal:client:eatFood')
AddEventHandler('mangal:client:eatFood', function(recipe)
    local ped = PlayerPedId()
    
    local animDict = "mp_player_inteat@burger"
    if LoadAnimDict(animDict) then
        TaskPlayAnim(ped, animDict, "mp_player_int_eat_burger", 8.0, -8.0, 3000, 49, 0, false, false, false)
        Wait(3000)
        ClearPedTasks(ped)
    end

    local pedHealth = GetEntityHealth(ped)
    local healthAmount = tonumber(recipe.healthAmount) or 0
    if healthAmount > 0 then
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), pedHealth + healthAmount))
    end

    local staminaAmount = tonumber(recipe.staminaAmount) or 0
    if staminaAmount > 0 then
        RestorePlayerStamina(PlayerId(), math.min(1.0, staminaAmount / 100.0))
    end

    ShowNotification(string.format(Config.Lang['ate_food'], recipe.label, recipe.hungerAmount))
end)

RegisterNetEvent('mangal:client:getPoisoned')
AddEventHandler('mangal:client:getPoisoned', function(settings)
    if isPoisoned then return end
    isPoisoned = true

    local durationMs = math.max(1000, (tonumber(settings and settings.duration) or Config.PoisonSettings.Duration or 20) * 1000)
    local tickMs = math.max(1000, (tonumber(settings and settings.tickInterval) or Config.PoisonSettings.TickInterval or 5) * 1000)
    local healthLoss = math.max(0, tonumber(settings and settings.healthLoss) or Config.PoisonSettings.HealthLoss or 15)
    local applyScreenEffect = settings and settings.applyScreenEffect == true
    local nauseaMs = math.max(0, (tonumber(settings and settings.nauseaDuration) or Config.PoisonSettings.NauseaDuration or 2) * 1000)
    local ped = PlayerPedId()

    ShowNotification(Config.Lang['food_nausea'], 'error', true)

    CreateThread(function()
        if nauseaMs > 0 then
            local nauseaStartedAt = GetGameTimer()
            while isPoisoned and GetGameTimer() - nauseaStartedAt < nauseaMs do
                ped = PlayerPedId()
                if applyScreenEffect and DoesEntityExist(ped) and not IsEntityDead(ped) then
                    SetTimecycleModifier('poison')
                    ShakeGameplayCam('DRUNK_SHAKE', 0.1)
                end
                Wait(250)
            end
        end

        if not isPoisoned then return end
        ShowNotification(Config.Lang['food_poisoned'], 'error', true)

        ped = PlayerPedId()
        if DoesEntityExist(ped) and not IsEntityDead(ped) then
            local animDict = 'anim@scripted@nightclub@vomit@'
            if LoadAnimDict(animDict) then
                TaskPlayAnim(ped, animDict, 'vomit', 8.0, -8.0, 10000, 1, 0, false, false, false)
            end
        end

        local startedAt = GetGameTimer()
        while isPoisoned and GetGameTimer() - startedAt < durationMs do
            ped = PlayerPedId()
            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                if applyScreenEffect then
                    SetTimecycleModifier('poison')
                    ShakeGameplayCam('DRUNK_SHAKE', 0.15)
                end
                SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - healthLoss))
            end
            Wait(tickMs)
        end

        ClearPedTasks(PlayerPedId())
        if applyScreenEffect then
            ClearTimecycleModifier()
            StopGameplayCamShaking(true)
        end
        isPoisoned = false
    end)
end)

-- ----------------------------------------------------
-- FALLBACK 3D TEXT THREAD
-- ----------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 1000

        if Config.Enable3DText then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local modelHash = GetValidGrillModel()

            local closestObject = GetClosestObjectOfType(coords.x, coords.y, coords.z, Config.InteractDistance, modelHash, false, false, false)
            if not DoesEntityExist(closestObject) then
                closestObject = GetClosestObjectOfType(coords.x, coords.y, coords.z, Config.InteractDistance, `prop_bbq_5`, false, false, false)
            end

            if DoesEntityExist(closestObject) and not isCooking then
                sleep = 0
                local objCoords = GetEntityCoords(closestObject)
                local netId = NetworkGetNetworkIdFromEntity(closestObject)
                local state = GrillStates[netId]

                if state then
                    local promptMsg = Config.Lang['prompt_empty']
                    local hasMeat = HasAnyMeatOnGrill(netId)
                    if state ~= 'LIT' and hasMeat then
                        promptMsg = Config.Lang['prompt_coal_out_with_meat']
                    elseif state == 'HAS_COAL' then
                        promptMsg = Config.Lang['prompt_has_coal']
                    elseif state == 'LIT' then
                        promptMsg = Config.Lang['prompt_lit']
                    end

                    DrawText3D(objCoords.x, objCoords.y, objCoords.z + 0.8, promptMsg)

                    if IsControlJustReleased(0, 38) then -- E
                        if state ~= 'LIT' and hasMeat then
                            openSlotMenu(netId)
                        elseif state == 'EMPTY' then
                            TriggerServerEvent('mangal:server:requestAddCoal', netId)
                        elseif state == 'HAS_COAL' then
                            TriggerServerEvent('mangal:server:requestLightGrill', netId)
                        elseif state == 'LIT' then
                            openAddMeatMenu(netId)
                        end
                    end

                    if IsControlJustReleased(0, 47) then -- G
                        TriggerEvent('mangal:client:startRemovingGrill', closestObject)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ----------------------------------------------------
-- NUI HEAT HUD YÖNETİCİ DÖNGÜSÜ
-- ----------------------------------------------------
local isNuiHudOpen = false
local lastNuiHudSignature = nil

CreateThread(function()
    while true do
        local sleep = 500

        if Config.UseNuiHeatHud then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local hudDist = Config.NuiHudDistance or 2.0

            local closestObj = GetClosestObjectOfType(coords.x, coords.y, coords.z, hudDist, `prop_bbq_5`, false, false, false)
            if not DoesEntityExist(closestObj) then
                closestObj = GetClosestObjectOfType(coords.x, coords.y, coords.z, hudDist, `prop_bbq_02`, false, false, false)
            end
            if not DoesEntityExist(closestObj) then
                local modelHash = GetValidGrillModel()
                closestObj = GetClosestObjectOfType(coords.x, coords.y, coords.z, hudDist, modelHash, false, false, false)
            end

            local closestNetId = DoesEntityExist(closestObj) and NetworkGetNetworkIdFromEntity(closestObj) or nil
            if DoesEntityExist(closestObj) and closestNetId and GrillStates[closestNetId] ~= nil then
                sleep = 250
                local netId = closestNetId
                local state = GrillStates[netId] or 'EMPTY'
                local heat = GrillHeat[netId] or 50
                local speedText = "Kömür Yok"
                local displayHeat = 0

                if state == 'EMPTY' then
                    speedText = "Kömür Yok"
                    displayHeat = 0
                elseif state == 'HAS_COAL' then
                    speedText = "Yakılmadı"
                    displayHeat = 0
                elseif state == 'LIT' then
                    displayHeat = heat
                    if heat >= (Config.HighHeatThreshold or 80) then
                        speedText = "1.75x Hızlı"
                    elseif heat < (Config.LowHeatThreshold or 40) then
                        speedText = "0.5x Yavaş"
                    else
                        speedText = "1.0x Normal"
                    end
                end

                local signature = string.format('%s:%s:%s:%s', netId, state, displayHeat, speedText)
                isNuiHudOpen = true
                if signature ~= lastNuiHudSignature then
                    lastNuiHudSignature = signature
                    SendNUIMessage({
                        action = 'updateHeatHud',
                        heat = displayHeat,
                        speedText = speedText
                    })
                end
            else
                if isNuiHudOpen then
                    isNuiHudOpen = false
                    lastNuiHudSignature = nil
                    SendNUIMessage({ action = 'closeHeatHud' })
                end
            end
        else
            if isNuiHudOpen then
                isNuiHudOpen = false
                lastNuiHudSignature = nil
                SendNUIMessage({ action = 'closeHeatHud' })
            end
        end

        Wait(sleep)
    end
end)

RegisterNetEvent('mangal:client:notify')
AddEventHandler('mangal:client:notify', function(msg, notifyType)
    ShowNotification(msg, notifyType)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    ReleaseNuiGrillUse()
    StopNuiGrillPose()
    UnregisterTargetSystem()
    if DoesEntityExist(pendingPlacementEntity) then DeleteEntity(pendingPlacementEntity) end
    for netId, _ in pairs(ActiveSounds) do
        StopGrillSound(netId)
    end
    for netId, _ in pairs(SlotProps) do
        DeleteAllSlotProps(netId)
    end
end)
