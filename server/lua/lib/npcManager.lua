local Registries = require("selene.registries")
local Entities = require("selene.entities")

local Constants = require("illarion-script-loader.server.lua.lib.constants")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
local RouteManager = require("illarion-script-loader.server.lua.lib.routeManager")

local m = {}

m.IdCounter = 0
m.EntitiesById = {}
m.EntitiesByNpcId = {}
m.PendingRemoval = {}

function m.Spawn(npc)
    local race = Registries.findByName("illarion:races", npc:getField("race"))
    if race == nil then
        error("Unknown race " .. npc:getField("race") .. " for NPC " .. npc:getName())
    end
    local entity = Entities.create(npc:getField("entity"))
    entity:setName(npc:getField("name"))
    entity:setCoordinate(npc:getField("x"), npc:getField("y"), npc:getField("z"))
    entity:setFacing(DirectionUtils.IllaToSelene(npc:getField("facing")))
    local id = npc:getMetadata("id") + Constants.NPC_BASE_ID
    entity:setCustomData(DataKeys.ID, id)
    entity:setCustomData(DataKeys.CharacterType, Character.npc)
    entity:setCustomData(DataKeys.NPC, npc)
    entity:setCustomData(DataKeys.Script, npc:getField("script"))
    entity:setCustomData(DataKeys.Race, race)
    entity:setCustomData(DataKeys.Sex, npc:getField("sex") == 1 and "female" or "male")
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
    entity:setCustomData(DataKeys.ID, m.IdCounter + Constants.DYNAMIC_NPC_BASE_ID)
    entity:setCustomData(DataKeys.CharacterType, Character.npc)
    entity:setCustomData(DataKeys.Script, scriptName)
    entity:setCustomData(DataKeys.Race, race)
    entity:setCustomData(DataKeys.Sex, sex)
    entity:spawn()
    m.EntitiesById[entity:getCustomData(DataKeys.ID)] = entity
    CharacterManager.AddEntity(entity)
end

function m.Despawn(entity)
    table.insert(m.PendingRemoval, entity)
end

function m.Update()
    for _, entity in ipairs(m.PendingRemoval) do
        local npc = entity:getCustomData(DataKeys.NPC)
        if npc then
            m.EntitiesByNpcId[npc:getMetadata("id")] = nil
        end
        m.EntitiesById[entity:getCustomData(DataKeys.ID)] = nil
        CharacterManager.RemoveEntity(entity)
        entity:despawn()
    end
    m.PendingRemoval = {}

    for _, entity in pairs(m.EntitiesById) do
        local npc = Character.fromSeleneEntity(entity)
        if not entity:getCustomData(DataKeys.Dead) then
            -- TODO run LTE
            -- TODO skip if no player nearby and not on route
            local status, script = pcall(require, entity:getCustomData(DataKeys.Script))
            if status and type(script.nextCycle) == "function" then
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
