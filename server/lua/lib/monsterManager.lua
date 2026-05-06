local Registries = require("selene.registries")
local Entities = require("selene.entities")

local Constants = require("illarion-script-loader.server.lua.lib.constants")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
local RouteManager = require("illarion-script-loader.server.lua.lib.routeManager")

local m = {}

m.IdCounter = 0
m.EntitiesById = {}
m.NewMonsters = {}

function m.Spawn(monsterDef, pos)
    local raceName = monsterDef:getField("race")
    local race = Registries.findByName("illarion:races", raceName)
    if not race then
        error("Unknown monster race " .. raceName)
    end

    local entity = Entities.create(race:getIdentifier():withPrefix("races/"):withSuffix("_0"))
    m.IdCounter = m.IdCounter + 1
    entity:setCustomData(DataKeys.ID, (m.IdCounter + Constants.MONSTER_BASE_ID) % (Constants.NPC_BASE_ID - Constants.MONSTER_BASE_ID))
    entity:setCustomData(DataKeys.CharacterType, Character.monster)
    entity:setCustomData(DataKeys.Race, race)
    entity:setCustomData(DataKeys.Monster, monsterDef)
    entity:setCustomData(DataKeys.Script, monsterDef:getField("script"))
    entity:setCoordinate(pos)
    table.insert(m.NewMonsters, entity)
    return Character.fromSeleneEntity(entity)
end

function m.Update()
    for _, entity in pairs(m.NewMonsters) do
        m.EntitiesById[entity:getCustomData(DataKeys.ID)] = entity
        CharacterManager.AddEntity(entity)
        entity:spawn()

        local status, script = pcall(require, entity:getCustomData(DataKeys.Script))
        if status and type(script.onSpawn) == "function" then
            script.onSpawn(Character.fromSeleneEntity(entity))
        end
    end
    m.NewMonsters = {}

    for _, entity in pairs(m.EntitiesById) do
        if not entity:getCustomData(DataKeys.Dead) then
            local monster = Character.fromSeleneEntity(entity)
            local routeStatus = RouteManager.Advance(monster)
            if routeStatus == "complete" or routeStatus == "blocked" then
                monster:setOnRoute(false)
                local status, script = pcall(require, entity:getCustomData(DataKeys.Script))
                if status and type(script.abortRoute) == "function" then
                    script.abortRoute(monster)
                end
            end
        end
    end
end

return m
