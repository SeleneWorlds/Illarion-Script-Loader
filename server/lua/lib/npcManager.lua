local Config = require("selene.config")
local Entities = require("selene.entities")
local Registries = require("selene.registries")

local Constants = require("illarion-script-loader.server.lua.lib.constants")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
local RouteManager = require("illarion-script-loader.server.lua.lib.routeManager")
local Events = require("illarion-script-loader.server.lua.lib.events")

local m = {}

local ACTIVE_RANGE = 60

m.IdCounter = 0
m.PendingRemoval = {}

local function isActive(npc)
    return npc:getOnRoute() or #world:getPlayersInRangeOf(npc.pos, ACTIVE_RANGE) > 0
end

function m.Spawn(npc)
    if npc:getField("enabled") ~= true then return end
    local raceName = npc:getField("race")
    local race = Registries.findByName("illarion:races", raceName)
    if not race then
        error("Unknown NPC race " .. tostring(raceName))
    end
    local entity = Entities.create(npc:getField("entity"))
    entity:setName(npc:getField("name"))
    local coordinate = npc:getField("coordinate")
    entity:setCoordinate(coordinate.x, coordinate.y, coordinate.z)
    entity:setFacing(npc:getField("facing"))
    local id = npc:getMetadata("id") + Constants.NPC_BASE_ID
    local charData = entity:getRuntimeData(DataKeys.Character)
    charData[DataFields.ID] = id
    charData[DataFields.CharacterType] = Character.npc
    charData[DataFields.NPC] = npc
    charData[DataFields.Script] = npc:getField("script")
    charData[DataFields.Race] = race:getMetadata("id")
    charData[DataFields.Sex] = npc:getField("sex") == 1 and "female" or "male"
    local character = Character.fromSeleneEntity(entity)
    for skillName, value in pairs(npc:getField("skills") or {}) do
        local skill = Registries.findByName("illarion:skills", skillName)
        local skillId = skill and tonumber(skill:getMetadata("id"))
        if skillId then
            character:setSkill(skillId, value, 0)
        end
    end
    if Config.getProperty("showNpcNameTags") == "true" then
        entity:addDynamicComponent("illarion:name", function(entity)
            return {
                type = "visual",
                visual = "illarion:labels/character",
                position = {
                    origin = "top",
                    offsetY = 20
                },
                overrides = {
                    text = entity:getName()
                }
            }
        end)
    end
    entity:spawn()
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
    CharacterManager.AddEntity(entity)
end

function m.Despawn(entity)
    if not entity then
        return false
    end
    table.insert(m.PendingRemoval, entity)
    return true
end

function m.FindStatic(identifier)
    for _, entity in ipairs(Entities.findAllByTag("illarion:character")) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        local definition = charData[DataFields.NPC]
        if charData[DataFields.CharacterType] == Character.npc
                and definition and definition:getName() == identifier then
            return entity
        end
    end
end

function m.RemoveStatic(identifier)
    local entity = m.FindStatic(identifier)
    if entity then
        entity:remove()
    end
end

function m.RemoveAllStatic()
    local entities = {}
    for _, entity in ipairs(Entities.findAllByTag("illarion:character")) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if charData[DataFields.CharacterType] == Character.npc and charData[DataFields.NPC] then
            entities[#entities + 1] = entity
        end
    end
    for _, entity in ipairs(entities) do
        entity:remove()
    end
end

function m.RemoveAll()
    local entities = {}
    for _, entity in ipairs(Entities.findAllByTag("illarion:character")) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if charData[DataFields.CharacterType] == Character.npc then
            entities[#entities + 1] = entity
        end
    end
    for _, entity in ipairs(entities) do
        entity:remove()
    end
    m.PendingRemoval = {}
end

function m.Update()
    for _, entity in ipairs(m.PendingRemoval) do
        entity:remove()
    end
    m.PendingRemoval = {}

    for _, entity in ipairs(Entities.findAllByTag("illarion:character")) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if charData[DataFields.CharacterType] == Character.npc then
            local npc = Character.fromSeleneEntity(entity)
            if charData[DataFields.Dead] then
                npc:increaseAttrib("hitpoints", 10000)
            elseif isActive(npc) then
                local event = { cancel = false }
                Events.onNpcCycle:fire(event, entity)

                local scriptName = charData[DataFields.Script]
                if scriptName and scriptName ~= "" then
                    local status, script = xpcall(require, scriptName)
                    if not event.cancel and status and type(script.nextCycle) == "function" then
                        thisNPC = npc
                        script.nextCycle(npc)
                    end
                end

                local routeStatus = RouteManager.Advance(npc)
                if routeStatus == "complete" or routeStatus == "blocked" then
                    npc:setOnRoute(false)
                    if status and type(script.abortRoute) == "function" then
                        script.abortRoute()
                    end
                end
            end
        end
    end
end

return m
