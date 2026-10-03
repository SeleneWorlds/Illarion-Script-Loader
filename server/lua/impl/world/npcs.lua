local Dimensions = require("selene.dimensions")
local Entities = require("selene.entities")
local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local NPCManager = require("illarion-script-loader.server.lua.lib.npcManager")

world.SeleneMethods.getNPCSInRangeOf = function(world, pos, range)
    local dimension = Dimensions.getDefault()
    local entities = dimension:getEntitiesInRange(pos, range)
    local npcs = {}
    for _, entity in ipairs(entities) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if charData[DataFields.CharacterType] == Character.npc then
            table.insert(npcs, Character.fromSeleneEntity(entity))
        end
    end
    return npcs
end

world.SeleneMethods.getNPCS = function(world)
    local npcs = {}
    for _, entity in ipairs(Entities.findAllByTag("illarion:character")) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if charData[DataFields.CharacterType] == Character.npc then
            table.insert(npcs, Character.fromSeleneEntity(entity))
        end
    end
    return npcs
end

world.SeleneMethods.deleteNPC = function(world, npcId)
    return NPCManager.Despawn(Entities.findByRuntimeData(DataKeys.Character, DataFields.ID, npcId))
end

world.SeleneMethods.createDynamicNPC = function(world, name, raceId, pos, sex, scriptName)
    local race = Registries.findByMetadata("illarion:races", "id", raceId)
    if race == nil then
        error("Unknown race id " .. raceId)
    end
    NPCManager.SpawnDynamic(name, race, sex == 1 and "female" or "male", pos, scriptName)
    return true
end
