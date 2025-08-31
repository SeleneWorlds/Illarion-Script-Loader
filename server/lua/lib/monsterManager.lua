local Constants = require("illarion-script-loader.server.lua.lib.constants")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")

local m = {}

m.IdCounter = 0
m.EntitiesById = {}
m.NewMonsters = {}

function m.Spawn(monsterDef, pos)
    local raceName = monsterDef:GetField("race")
    local race = Registries.FindByName("illarion:races", raceName)
    if not race then
        error("Unknown monster race " .. raceName)
    end

    local entity = Entities.Create(race.Name .. "_0")
    idCounter = idCounter + 1
    entity.CustomData[DataKeys.ID] = (idCounter + Constants.MONSTER_BASE_ID) % (Constants.NPC_BASE_ID - Constants.MONSTER_BASE_ID)
    entity.CustomData[DataKeys.CharacterType] = Character.monster
    entity.CustomData[DataKeys.Race] = race
    entity.CustomData[DataKeys.Monster] = monsterDef
    entity.CustomData[DataKeys.Script] = monsterDef:GetField("script")
    entity:SetCoordinate(pos)
    table.insert(m.NewMonsters, entity)
    return Character.fromSeleneEntity(entity)
end

function m.Update()
    for _, entity in pairs(m.NewMonsters) do
        m.EntitiesById[entity.CustomData[DataKeys.ID]] = entity
        CharacterManager.AddEntity(entity)
        entity:Spawn()

        local status, script = pcall(require, entity.CustomData[Script])
        if status and type(script.onSpawn) == "function" then
            script.onSpawn(Character.fromSeleneEntity(entity))
        end
    end
    m.NewMonsters = {}
end

return m