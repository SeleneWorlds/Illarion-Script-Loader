local Dimensions = require("selene.dimensions")
local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local NPCManager = require("illarion-script-loader.server.lua.lib.npcManager")

world.SeleneMethods.getNPCSInRangeOf = function(world, pos, range)
    local dimension = Dimensions.GetDefault()
    local entities = dimension:GetEntitiesInRange(pos, range)
    local npcs = {}
    for _, entity in ipairs(entities) do
        if entity.CustomData[DataKeys.CharacterType] == Character.npc then
            table.insert(npcs, Character.fromSeleneEntity(entity))
        end
    end
    return npcs
end

world.SeleneMethods.getNPCS = function(world)
    local npcs = {}
    for _, npc in pairs(NPCManager.EntitiesByNpcId) do
        table.insert(npcs, NPCManager.EntitiesByNpcId)
    end
    return npcs
end

world.SeleneMethods.deleteNPC = function(world, npcId)
    NPCManager.Despawn(NPCManager.EntitiesByNpcId[npcId])
end

world.SeleneMethods.createDynamicNPC = function(world, name, raceId, pos, sex, scriptName)
    local race = Registries.FindByMetadata("illarion:races", "id", raceId)
    if race == nil then
        error("Unknown race id " .. raceId)
    end
    NPCManager.SpawnDynamic(name, race, sex == 1 and "female" or "male", pos, scriptName)
    return true
end