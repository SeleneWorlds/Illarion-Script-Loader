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
    local entity = Entities.create("illarion:races/race_0_1")
    local id = 8147
    entity:setCustomData(DataKeys.ID, id)
    entity:setCustomData(DataKeys.CharacterType, Character.player)
    entity:setCustomData(DataKeys.Race, Registries.findByName("illarion:races", "illarion:race_0"))
    entity:setCustomData(DataKeys.Sex, "female")
    entity:setCoordinate(702, 283, 0)
    entity:addDynamicComponent("illarion:name", function(entity, forPlayer)
        local isControlled = forPlayer:getControlledEntity() == entity
        local isIntroduced = forPlayer:getControlledEntity() and forPlayer:getControlledEntity():getCustomData(DataKeys.Introduction(entity:getCustomData(DataKeys.ID)))
        local effectiveName = entity:getName()
        if not isIntroduced and not isControlled then
            local race = entity:getCustomData(DataKeys.Race)
            if race then
                local sex = entity:getCustomData(DataKeys.Sex) or "male"
                local key = "nameTag." .. stringx.substringAfter(race:getName(), "illarion:") .. "." .. sex
                effectiveName = I18n.Get(key, player.Locale) or key
            else
                effectiveName = tostring(entity:getCustomData(DataKeys.Race))
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

    local inventory = InventoryManager.GetInventory(character)
    inventory:subscribe(function(data)
        local slotId = data.dirtySlot
        if slotId then
            local item = inventory:getItem(slotId)
            Network.sendToEntity(entity, "illarion:update_slot", {
                viewId = "inventory",
                slotId = slotId,
                item = item and { visual = item.def:getField("visual") } or nil
            })
        end
    end)

    character:setAttrib("hitpoints", 10000)
    character:setAttrib("foodlevel", 30000)
    character:setMentalCapacity(10000)

    player:setCustomData(DataKeys.CurrentLoginTimestamp, os.time())

    return character
end

function m.Despawn(player)
    if player:getControlledEntity() then
        player:getControlledEntity():remove()
    end

    local loginTimestamp = player:getCustomData(DataKeys.CurrentLoginTimestamp) or 0
    local logoutTimestamp = os.time()
    local sessionOnlineTime = logoutTimestamp - loginTimestamp
    local totalOnlineTime = player:getCustomData(DataKeys.TotalOnlineTime) or 0
    player:setCustomData(DataKeys.TotalOnlineTime, totalOnlineTime + sessionOnlineTime)
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