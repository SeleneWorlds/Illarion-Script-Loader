local Players = require("selene.players")
local Entities = require("selene.entities")
local Registries = require("selene.registries")
local Network = require("selene.network")
local I18n = require("selene.i18n")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

local m = {}

m.EntitiesById = {}

function m.Spawn(player)
    local entity = Entities.create("illarion:races/race_0_1")
    local id = 8147
    local charData = entity:getRuntimeData(DataKeys.Character)
    charData[DataFields.ID] = id
    charData[DataFields.CharacterType] = Character.player
    local race = Registries.findByName("illarion:races", "illarion:race_0")
    charData[DataFields.Race] = race:getMetadata("id")
    charData[DataFields.Sex] = "female"
    entity:setCoordinate(702, 283, 0)
    entity:addDynamicComponent("illarion:name", function(entity, forPlayer)
        local targetCharData = entity:getRuntimeData(DataKeys.Character)
        local isControlled = forPlayer:getControlledEntity() == entity
        local introductionData = forPlayer:getControlledEntity() and forPlayer:getControlledEntity():getRuntimeData(DataKeys.Introductions) or nil
        local isIntroduced = introductionData and introductionData[targetCharData[DataFields.ID]]
        local effectiveName = entity:getName()
        if not isIntroduced and not isControlled then
            local raceId = targetCharData[DataFields.Race]
            local race = Registries.findByMetadata("illarion:races", "id", raceId)
            if race then
                local sex = targetCharData[DataFields.Sex] or "male"
                local key = "nameTag." .. stringx.substringAfter(race:getName(), "illarion:") .. "." .. sex
                effectiveName = I18n.get(key, player.Locale) or key
            else
                effectiveName = tostring(targetCharData[DataFields.Race])
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
    entity:spawn()
    player:setControlledEntity(entity)
    player:setCameraEntity(entity)
    player:setCameraToFollowTarget()

    m.EntitiesById[id] = entity
    local character = CharacterManager.AddEntity(entity)

    local equipment = InventoryManager.GetEquipment(character)
    equipment:subscribe(function(data)
        local slotId = data.dirtySlot
        if slotId then
            local item = equipment:getItem(slotId)
            Network.sendToEntity(entity, "illarion:update_slot", {
                viewId = "equipment",
                slotId = slotId,
                item = item and { visual = item.def:getField("visual") } or nil
            })
        end
    end)
    local belt = InventoryManager.GetBelt(character)
    belt:subscribe(function(data)
        local slotId = data.dirtySlot
        if slotId then
            local item = belt:getItem(slotId)
            Network.sendToEntity(entity, "illarion:update_slot", {
                viewId = "belt",
                slotId = slotId,
                item = item and { visual = item.def:getField("visual") } or nil
            })
        end
    end)

    character:setAttrib("hitpoints", 10000)
    character:setAttrib("foodlevel", 30000)
    character:setMentalCapacity(10000)

    local playerData = player:getRuntimeData(DataKeys.Player)
    playerData[DataFields.CurrentLoginTimestamp] = os.time()

    return character
end

function m.Despawn(player)
    if player:getControlledEntity() then
        player:getControlledEntity():remove()
    end

    local playerData = player:getRuntimeData(DataKeys.Player)
    local loginTimestamp = playerData[DataFields.CurrentLoginTimestamp] or 0
    local logoutTimestamp = os.time()
    local sessionOnlineTime = logoutTimestamp - loginTimestamp
    local totalOnlineTime = playerData[DataFields.TotalOnlineTime] or 0
    playerData[DataFields.TotalOnlineTime] = totalOnlineTime + sessionOnlineTime
end

function m.getPlayerByCharacterName(name)
    for _, player in ipairs(Players.getOnlinePlayers()) do
        if player:getControlledEntity() and player:getControlledEntity():getName() == name then
            return player
        end
    end
    return nil
end

return m
