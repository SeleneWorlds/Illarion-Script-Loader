local Registries = require("selene.registries")
local Entities = require("selene.entities")

local Constants = require("illarion-script-loader.server.lua.lib.constants")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
local RouteManager = require("illarion-script-loader.server.lua.lib.routeManager")

local m = {}

m.IdCounter = 0
m.EntitiesById = {}
m.EntitiesByNpcId = {}
m.PendingRemoval = {}

function m.Spawn(npc)
    local entity = Entities.create(npc:getField("entity"))
    entity:setName(npc:getField("name"))
    entity:setCoordinate(npc:getField("x"), npc:getField("y"), npc:getField("z"))
    entity:setFacing(DirectionUtils.IllaToSelene(npc:getField("facing")))
    local id = npc:getMetadata("id") + Constants.NPC_BASE_ID
    local charData = entity:getRuntimeData(DataKeys.Character)
    charData[DataFields.ID] = id
    charData[DataFields.CharacterType] = Character.npc
    charData[DataFields.NPC] = npc
    charData[DataFields.Script] = npc:getField("script")
    charData[DataFields.Race] = npc:getField("race")
    charData[DataFields.Sex] = npc:getField("sex") == 1 and "female" or "male"
    entity:spawn()
    m.EntitiesById[id] = entity
    m.EntitiesByNpcId[npc:getMetadata("id")] = entity
    CharacterManager.AddEntity(entity)
end

function m.SpawnDynamic(name, race, sex, pos, scriptName)
    local raceId = race:getMetadata("id")
    local typeId = sex == "female" and 1 or 0
    local entityType = "illarion:race_" .. raceId .. "_" .. typeId
    local entity = Entities.create(entityType)
    entity:setName(name)
    entity:setCoordinate(pos)
    m.IdCounter = m.IdCounter + 1
    local charData = entity:getRuntimeData(DataKeys.Character)
    charData[DataFields.ID] = m.IdCounter + Constants.DYNAMIC_NPC_BASE_ID
    charData[DataFields.CharacterType] = Character.npc
    charData[DataFields.Script] = scriptName
    charData[DataFields.Race] = raceId
    charData[DataFields.Sex] = sex
    entity:spawn()
    m.EntitiesById[charData[DataFields.ID]] = entity
    CharacterManager.AddEntity(entity)
end

function m.Despawn(entity)
    table.insert(m.PendingRemoval, entity)
end

function m.Update()
    for _, entity in ipairs(m.PendingRemoval) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        local npc = charData[DataFields.NPC]
        if npc then
            m.EntitiesByNpcId[npc:getMetadata("id")] = nil
        end
        m.EntitiesById[charData[DataFields.ID]] = nil
        CharacterManager.RemoveEntity(entity)
        entity:despawn()
    end
    m.PendingRemoval = {}

    for _, entity in pairs(m.EntitiesById) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        local npc = Character.fromSeleneEntity(entity)
        if not charData[DataFields.Dead] then
            -- TODO run LTE
            -- TODO skip if no player nearby and not on route
            local status, script = pcall(require, charData[DataFields.Script])
            if status and type(script.nextCycle) == "function" then
                thisNPC = npc
                script.nextCycle(npc)
            end

            local routeStatus = RouteManager.Advance(npc)
            if routeStatus == "complete" or routeStatus == "blocked" then
                npc:setOnRoute(false)
                if status and type(script.abortRoute) == "function" then
                    script.abortRoute()
                end
            end
        else
            npc:increaseAttrib("hitpoints", 10000)
        end
    end
end

return m
