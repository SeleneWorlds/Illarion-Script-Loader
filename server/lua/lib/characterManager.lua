local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local m = {}

m.EntitiesById = {}
m.CharactersById = {}

function m.AddEntity(entity)
    local charData = entity:getRuntimeData(DataKeys.Character)
    local id = charData[DataFields.ID]
    if id == nil then
        error("Tried to add an entity without an ID to character manager")
    end
    m.EntitiesById[id] = entity
    local character = Character.fromSeleneEntity(entity)
    m.CharactersById[id] = character
    return character
end

function m.RemoveEntity(entity)
    local charData = entity:getRuntimeData(DataKeys.Character)
    local id = charData[DataFields.ID]
    m.EntitiesById[id] = nil
    m.CharactersById[id] = nil
end

function m.IsDead(character)
    local charData = character.SeleneEntity:getRuntimeData(DataKeys.Character)
    return charData[DataFields.Dead]
end

function m.SetDead(character, dead)
    local wasDead = m.IsDead(character)
    local charData = character.SeleneEntity:getRuntimeData(DataKeys.Character)
    charData[DataFields.Dead] = dead
    if not wasDead and dead then
        local characterType = charData[DataFields.CharacterType]
        if characterType == Character.player then
            character:abortAction()
            illaPlayerDeath.playerDeath(character)
        elseif characterType == Character.monster then
            local scriptName = charData[DataFields.Script]
            if scriptName then
                local status, script = pcall(require, scriptName)
                if status and type(script.onDeath) == "function" then
                    local illaMonster = Character.fromSeleneEntity(character.SeleneEntity)
                    script.onDeath(illaMonster)
                end
            end
        end
    end
end

return m
