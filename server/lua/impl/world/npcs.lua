local Dimensions = require("selene.dimensions")
local Entities = require("selene.entities")
local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local NPCManager = require("illarion-script-loader.server.lua.lib.npcManager")

world.SeleneMethods.getNPCSInRangeOf = function(world, pos, range)
    range = assert(tonumber(range), "range must be a number, was " .. tostring(range))
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
    npcId = assert(tonumber(npcId), "npcId must be a number, was " .. tostring(npcId))
    return NPCManager.Despawn(Entities.findByRuntimeData(DataKeys.Character, DataFields.ID, npcId))
end

world.SeleneMethods.createDynamicNPC = function(world, name, raceId, pos, sex, scriptName)
    raceId = assert(tonumber(raceId), "raceId must be a number, was " .. tostring(raceId))
    sex = assert(tonumber(sex), "sex must be a number, was " .. tostring(sex))
    local race = Registries.findByMetadata("illarion:races", "id", raceId)
    if race == nil then
        error("Unknown race id " .. raceId)
    end
    local entity = NPCManager.SpawnDynamic(name, race, sex == 1 and "female" or "male", pos, scriptName)
    return true, Character.fromSeleneEntity(entity)
end
