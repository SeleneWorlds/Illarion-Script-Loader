local Players = require("selene.players")
local Entities = require("selene.entities")
local Registries = require("selene.registries")
local Network = require("selene.network")
local I18n = require("selene.i18n")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

local m = {}

m.EntitiesById = {}

function m.Spawn(player)
    local entity = Entities.Create("illarion:race_0_1")
    local id = 8147
    entity.CustomData[DataKeys.ID] = id
    entity.CustomData[DataKeys.CharacterType] = Character.player
    entity.CustomData[DataKeys.Race] = Registries.FindByName("illarion:races", "illarion:race_0")
    entity.CustomData[DataKeys.Sex] = "female"
    entity:SetCoordinate(702, 283, 0)
    entity:AddDynamicComponent("illarion:name", function(entity, forPlayer)
        local isControlled = forPlayer.ControlledEntity == entity
        local isIntroduced = forPlayer.ControlledEntity and forPlayer.ControlledEntity.CustomData[DataKeys.Introduction(entity.CustomData[DataKeys.ID])]
        local effectiveName = entity.Name
        if not isIntroduced and not isControlled then
            local race = entity.CustomData[DataKeys.Race]
            if race then
                local sex = entity.CustomData[DataKeys.Sex] or "male"
                local key = "nameTag." .. stringx.substringAfter(race.Name, "illarion:") .. "." .. sex
                effectiveName = I18n.Get(key, player.Locale) or key
            else
                effectiveName = tostring(entity.CustomData:RawLookup(DataKeys.Race))
            end
        end
        return {
            type = "visual",
            visual = "illarion:labels/character",
            position = {
                origin = "top",
                offsetY = 20
            },
            overrides = {
                text = effectiveName
            }
        }
    end)
    entity:Spawn()
    player.ControlledEntity = entity
    player.CameraEntity = entity
    player:SetCameraToFollowTarget()

    m.EntitiesById[id] = entity
    local character = CharacterManager.AddEntity(entity)

    local inventory = InventoryManager.GetInventory(character)
    inventory:subscribe(function(data)
        local slotId = data.dirtySlot
        if slotId then
            local item = inventory:getItem(slotId)
            Network.SendToEntity(entity, "illarion:update_slot", {
                viewId = "inventory",
                slotId = slotId,
                item = item and { visual = item.def:GetField("visual") } or nil
            })
        end
    end)

    character:setAttrib("hitpoints", 10000)
    character:setAttrib("foodlevel", 30000)
    character:setMentalCapacity(10000)

    player.CustomData[DataKeys.CurrentLoginTimestamp] = os.time()

    return character
end

function m.Despawn(player)
    player.ControlledEntity:Remove()

    local loginTimestamp = player.CustomData[DataKeys.CurrentLoginTimestamp] or 0
    local logoutTimestamp = os.time()
    local sessionOnlineTime = logoutTimestamp - loginTimestamp
    local totalOnlineTime = player.CustomData[DataKeys.TotalOnlineTime] or 0
    player.CustomData[DataKeys.TotalOnlineTime] = totalOnlineTime + sessionOnlineTime
end

function m.getPlayerByCharacterName(name)
    for _, player in ipairs(Players.GetOnlinePlayers()) do
        if player.ControlledEntity and player.ControlledEntity.Name == name then
            return player
        end
    end
    return nil
end

return m