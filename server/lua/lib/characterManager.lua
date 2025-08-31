local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local m = {}

m.EntitiesById = {}
m.CharactersById = {}

function m.AddEntity(entity)
    local id = entity.CustomData[DataKeys.ID]
    if id == nil then
        error("Tried to add an entity without an ID to character manager")
    end
    m.EntitiesById[id] = entity
    local character = Character.fromSeleneEntity(entity)
    m.CharactersById[id] = character
    return character
end

function m.RemoveEntity(entity)
    m.EntitiesById[entity.CustomData[DataKeys.ID]] = nil
end

function m.IsDead(character)
    return character.SeleneEntity.CustomData[DataKeys.Dead]
end

function m.SetDead(character, dead)
    local wasDead = m.IsDead(character)
    character.SeleneEntity.CustomData[DataKeys.Dead] = dead
    if not wasDead and dead then
        local characterType = character.SeleneEntity.CustomData[DataKeys.CharacterType]
        if characterType == Character.player then
            character:abortAction()
            illaPlayerDeath.playerDeath(character)
        elseif characterType == Character.monster then
            local scriptName = character.SeleneEntity.CustomData[DataKeys.Script]
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