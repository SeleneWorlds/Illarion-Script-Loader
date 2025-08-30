local Constants = require("illarion-script-loader.server.lua.lib.constants")

local m = {}

m.IdCounter = 0
m.MonstersById = {}
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
    local scriptName = monsterDef:GetField("script")
    if scriptName then
        local status, script = pcall(require, scriptName)
        if status, script then
            entity.CustomData[DataKeys.MonsterScript] = script
        else
            error("Failed to load script " .. scriptName .. " for monster " .. monsterDef.Name)
        end
    end
    entity:SetCoordinate(pos)
    table.insert(m.NewMonsters, entity)
end

function m.Update()
    for _, entity in pairs(m.NewMonsters) do
        m.MonstersById[entity.CustomData[DataKeys.ID]] = entity
        entity:Spawn()

        local script = entity.CustomData[DataKeys.MonsterScript]
        if script and type(script.onSpawn) == "function" then
            script.onSpawn(Character.fromSeleneEntity(entity))
        end
    end
    m.NewMonsters = {}
end

return m