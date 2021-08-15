local Tunnel = module("_core", "lib/Tunnel")
local Proxy = module("_core", "lib/Proxy")

cAPI = Proxy.getInterface("API")
API = Tunnel.getInterface("API")


doorexplosed = false

local interiors = {
    --   [1] = 72962, -- BANCO BLACKWATER
   -- [2] = 42754, -- BANCO SAINT DENNIS
    [3] = 29442 -- BANCO RHODES
    --  [4] = 12290 -- BANCO VALENTINE
}

local interiorIndexBeingRobbed = nil
local interiorIndexPlayerIsIn = nil

local isParticipantOfRobbery = false
local isBlockedByRobbery = false

local secondsUntilRobberyEnds = nil
local secondsUntilAbandonRobbery = nil

local shootingToStartCooldown = false


Citizen.CreateThread(
    function()
        while true do
            Citizen.Wait(1000)

            local ped = PlayerPedId()

            local interiorIdPlayerIsIn = GetInteriorFromEntity(ped)

            if interiorIdPlayerIsIn ~= 0 then
                for index, interiorId in pairs(interiors) do
                    if interiorIdPlayerIsIn == interiorId then
                        interiorIndexPlayerIsIn = index
                    end
                end
            else
                interiorIndexPlayerIsIn = nil
            end
        end
    end
)


Citizen.CreateThread(
    function()
        ClearPedTasksImmediately(PlayerPedId())
        local hashUnarmed = GetHashKey("WEAPON_UNARMED")
        while true do
            Citizen.Wait(0)

            if interiorIndexPlayerIsIn ~= nil then
                local ped = PlayerPedId()
                local retval, weaponHash = GetCurrentPedWeapon(ped, 1)
                if weaponHash ~= hashUnarmed then
                    if interiorIndexBeingRobbed == nil then
                        if not shootingToStartCooldown then
                            notify("Shoot to start the robbery.")
                            if IsPedShooting(ped) then
                                initShootingCountdown()
                                notify("Go to the bank vault!")

                                local playerId = PlayerId()
                                local interiorIdPlayerIsIn = interiors[interiorIndexPlayerIsIn]

                                local participants = {
                                    GetPlayerServerId(playerId)
                                }

                                for _, activePlayerId in pairs(GetActivePlayers()) do
                                    if activePlayerId ~= playerId then
                                        local activePlayerPed = GetPlayerPed(activePlayerId)
                                        if activePlayerPed ~= 0 then
                                            local activePlayerPedInterior = GetInteriorFromEntity(activePlayerPed)
                                            if activePlayerPedInterior == interiorIdPlayerIsIn then
                                                table.insert(participants, GetPlayerServerId(activePlayerId))
                                            end
                                        end
                                    end
                                end

                                if NetworkIsSessionActive() == 1 then
                                    TriggerServerEvent("FRP:ROBBERY:TryToStartRobbery", interiorIndexPlayerIsIn, participants)
                                else
                                    cAPI.notify("error", "You're alone!")
                                end
                            end
                        else
                        end
                    else
                        if IsPedShooting(ped) then
                        end
                    end
                end

                if isBlockedByRobbery then
                    if interiorIndexBeingRobbed == nil then
                        isBlockedByRobbery = false
                        RemoveAnimDict("random@arrests@busted")
                        ClearPedTasks(ped)
                    else

                        if weaponHash ~= hashUnarmed then
                            SetCurrentPedWeapon(ped, hashUnarmed, true)
                        end
                        if not IsEntityPlayingAnim(ped, "script_proc@robberies@homestead@lonnies_shack@deception", "hands_up_loop", 3) then
                            TaskPlayAnim(ped, "script_proc@robberies@homestead@lonnies_shack@deception", "hands_up_loop",  2.0, -2.0, -1, 67109393, 0.0, false, 1245184, false, "UpperbodyFixup_filter", false)
                        end
                    end
                end
                if interiorIndexPlayerIsIn == interiorIndexBeingRobbed then
                    if secondsUntilRobberyEnds ~= nil then
                        local minutes = math.floor((secondsUntilRobberyEnds % 3600) / 60)
                        local seconds = secondsUntilRobberyEnds % 60
                        drawText(minutes .. " min and " .. seconds .. " seconds", true)
                    end
                end
            else
                if secondsUntilAbandonRobbery ~= nil then
                    drawText("~r~Come back in the bank! " .. math.floor((secondsUntilAbandonRobbery / 10)) .. " seconde restante", true)
                end
            end
        end
    end
)


function initCheckPedIsOutside()
    isParticipantOfRobbery = true
    Citizen.CreateThread(
        function()
            local defaultSeconds = 5
            defaultSeconds = defaultSeconds * 10 -- 100ms (Wait) * 50 = 5000ms
            secondsUntilAbandonRobbery = defaultSeconds
            while isParticipantOfRobbery do
                Citizen.Wait(100)

                local ped = PlayerPedId()

                local interiorIdBeingRobbed = interiors[interiorIndexBeingRobbed]
                local interiorIdPlayerIsIn = GetInteriorFromEntity(ped)

                if interiorIdPlayerIsIn ~= interiorIdBeingRobbed then
                    if secondsUntilAbandonRobbery == nil then
                        secondsUntilAbandonRobbery = defaultSeconds
                    end

                    secondsUntilAbandonRobbery = secondsUntilAbandonRobbery - 1 -- Wait ms
                    if secondsUntilAbandonRobbery <= 0 then
                        if not isBlockedByRobbery then
                            -- print("Você ficou tempo demais fora do roubo")
                            TriggerServerEvent("FRP:ROBBERY:PlayerAbandonedRobbery")
                        else
                            -- print("Você ficou tempo demais fora do roubo blocked")
                            isBlockedByRobbery = false
                            ClearPedTasks(ped)
                        end

                        TriggerEvent("FRP:ROBBERY:EndRobbery")

                        break
                    end
                else
                    if secondsUntilAbandonRobbery ~= nil then
                        secondsUntilAbandonRobbery = nil
                    end
                end
            end

            if not isParticipantOfRobbery then
                local ped = PlayerPedId()
                if IsEntityPlayingAnim(ped, "random@arrests@busted", "idle_a", 3) then
                    ClearPedTasks(ped)
                end
            end
        end
    )
end

function initSecondsCountdown(seconds)
    -- print("got seconds", seconds)
    secondsUntilRobberyEnds = seconds

    Citizen.CreateThread(
        function()
            while secondsUntilRobberyEnds ~= nil do
                Citizen.Wait(1000)
                if secondsUntilRobberyEnds ~= nil then
                    secondsUntilRobberyEnds = secondsUntilRobberyEnds - 1

                    if secondsUntilRobberyEnds == 0 then
                        secondsUntilRobberyEnds = nil
                    end
                end
            end
        end
    )
end

function initShootingCountdown()
    shootingToStartCooldown = true
    seconds = 10

    Citizen.CreateThread(
        function()
            while seconds > 0 do
                Citizen.Wait(1000)
                seconds = seconds - 1
            end
            shootingToStartCooldown = false
        end
    )
end

local square = math.sqrt
function getDistance(a, b) 
    local x, y, z = a.x-b.x, a.y-b.y, a.z-b.z
    return square(x*x+y*y+z*z)
end

function drawText(str, center)
    local x = 0.87
    local y = 1
    if lastDisplayedText == nil or lastDisplayedText ~= str then
        lastDisplayedText = str
        lastVarString = CreateVarString(10, "LITERAL_STRING", str)
    end
    SetTextScale(0.4, 0.4)
    SetTextColor(255, 255, 255, 255)
    Citizen.InvokeNative(0xADA9255D, 1)
    --DisplayText(str, x, y)
    if center then
        SetTextCentre(center)
        DisplayText(lastVarString, x, y)
    elseif alignRight then
        DisplayText(lastVarString, x + 0.15, y)
    else
        DisplayText(lastVarString, x, y)
    end
end

function DrawTxt(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
    local str = CreateVarString(10, "LITERAL_STRING", str, Citizen.ResultAsLong())
    SetTextScale(w, h)
    SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
    SetTextCentre(centre)
    if enableShadow then
      SetTextDropshadow(1, 0, 0, 0, 255)
    end
    Citizen.InvokeNative(0xADA9255D, 10)
    DisplayText(str, x, y)
  end

  function LoadModel(model)
    local attempts = 0
    while attempts < 100 and not HasModelLoaded(model) do
        RequestModel(model)
        Citizen.Wait(10)
        attempts = attempts + 1
    end
    return IsModelValid(model)
end


RegisterNetEvent("FRP:ROBBERY:Bolsa")
AddEventHandler(
    "FRP:ROBBERY:Bolsa",
    function()
        --   cAPI.AddWantedTime(true, 30)

    end
)

function InitVaultRobberyStart()
     animDict = "script_story@nbd1@ig@ig_10_placingdynamite"
     modelHash = GetHashKey("w_throw_dynamite03")
     doorsentity = GetHashKey("p_door_val_bankvault")
     entity2 = GetHashKey("p_door_val_bankvault")
     moneybag = GetHashKey("p_moneybag01x") 
    Citizen.CreateThread(
        function()
            while true do
              Citizen.Wait(0)
              local playerPed = PlayerPedId()
              local coords = GetEntityCoords(playerPed)
              local boneIndex = GetEntityBoneIndexByName(ped, "SKEL_R_HAND")
              for _, v in pairs(Config.Bankpos) do
            if doorexplosed == false then
                if getDistance(coords, v) < 2 then
                    DrawTxt("Press E to explode the door ", 0.85, 0.95, 0.4, 0.4, true, 255, 255, 255, 255, true, 10000)
                    if IsControlJustReleased(0, 0xCEFD9220) then
                        LoadModel(modelHash)
                        entity = CreateObject(modelHash, 1282.897705078125, -1308.8197021484375, 77.0, true, false, false)
                        SetEntityVisible(entity, true)
                        SetEntityAlpha(entity, 255, false)
                        AttachEntityToEntity(entity, entity2, boneIndex,  1282.897705078125, -1308.8197021484375, 77.0, 0.0, 100.0, 68.0, false, false, false, true, 2, true)
                       RequestAnimDict(animDict)
                       while not HasAnimDictLoaded(animDict) do
                        Citizen.Wait(100)
                       end
                       TaskPlayAnim(PlayerPedId(), animDict, "left_nogun_2hands_look_01_arthur", 8.0, 8.0, 3000, 31, 0, true, 0, false, 0, false)
                       Citizen.Wait(10000)
                       AddExplosion(1282.897705078125, -1308.8197021484375, 77.0, 31, 50.0, true, false, 10)
                       DeleteEntity(entity)
                       CreateModelHide(1282.536376953125,-1309.31591796875,76.03642272949219, 0, "p_door_val_bankvault", true)
                       doorexplosed = true 
                    end
                end
            end
            end
        end
    end
 )
end




RegisterNetEvent("FRP:ROBBERY:StartRobbery")
AddEventHandler(
    "FRP:ROBBERY:StartRobbery",
    function(index, asParticipant, seconds)
        interiorIndexBeingRobbed = index
        if asParticipant then
            initCheckPedIsOutside()
            initSecondsCountdown(seconds)
            InitVaultRobberyStart()
            cAPI.AddWantedTime(true, 30)
        end
        TriggerEvent("FRP:TOAST:New", "alert", "robbery will finish in  " .. seconds .. " seconds")
    end
)

RegisterNetEvent("FRP:ROBBERY:EndRobbery")
AddEventHandler(
    "FRP:ROBBERY:EndRobbery",
    function()
        interiorIndexBeingRobbed = nil

        isParticipantOfRobbery = false
        isBlockedByRobbery = false

        secondsUntilRobberyEnds = nil
        secondsUntilAbandonRobbery = nil
        shootingToStartCooldown = false
    end
)

function notify(_message)
    local str = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", _message, Citizen.ResultAsLong())
    SetTextScale(0.25, 0.25)
    SetTextCentre(1)
    Citizen.InvokeNative(0xFA233F8FE190514C, str)
    Citizen.InvokeNative(0xE9990552DEC71600)
end
