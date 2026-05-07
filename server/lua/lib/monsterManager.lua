local Registries = require("selene.registries")
local Entities = require("selene.entities")

local Constants = require("illarion-script-loader.server.lua.lib.constants")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
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
    local charData = entity:getRuntimeData(DataKeys.Character)
    charData[DataFields.ID] = (m.IdCounter + Constants.MONSTER_BASE_ID) % (Constants.NPC_BASE_ID - Constants.MONSTER_BASE_ID)
    charData[DataFields.CharacterType] = Character.monster
    charData[DataFields.Race] = race:getMetadata("id")
    charData[DataFields.Monster] = monsterDef
    charData[DataFields.Script] = monsterDef:getField("script")
    entity:setCoordinate(pos)
    table.insert(m.NewMonsters, entity)
    return Character.fromSeleneEntity(entity)
end

function m.Update()
    for _, entity in pairs(m.NewMonsters) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        m.EntitiesById[charData[DataFields.ID]] = entity
        CharacterManager.AddEntity(entity)
        entity:spawn()

        local status, script = pcall(require, charData[DataFields.Script])
        if status and type(script.onSpawn) == "function" then
            script.onSpawn(Character.fromSeleneEntity(entity))
        end
    end
    m.NewMonsters = {}

    for _, entity in pairs(m.EntitiesById) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if not charData[DataFields.Dead] then
            local monster = Character.fromSeleneEntity(entity)
            local routeStatus = RouteManager.Advance(monster)
            if routeStatus == "complete" or routeStatus == "blocked" then
                monster:setOnRoute(false)
                local status, script = pcall(require, charData[DataFields.Script])
                if status and type(script.abortRoute) == "function" then
                    script.abortRoute(monster)
                end
            end
        end
    end
end

return m
