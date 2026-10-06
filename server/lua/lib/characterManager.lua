local Entities = require("selene.entities")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local m = {}

function m.AddEntity(entity)
    local charData = entity:getRuntimeData(DataKeys.Character)
    local id = charData[DataFields.ID]
    if id == nil then
        error("Tried to add an entity without an ID to character manager")
    end
    return Character.fromSeleneEntity(entity)
end

function m.IsDead(character)
    local charData = character.SeleneEntity:getRuntimeData(DataKeys.Character)
    return charData[DataFields.Dead]
end

function m.SetDead(character, dead)
    local wasDead = m.IsDead(character)
    local charData = character.SeleneEntity:getRuntimeData(DataKeys.Character)
    charData[DataFields.Dead] = dead
    if wasDead ~= dead then
        character.SeleneEntity:updateVisuals()
    end
    if not wasDead and dead then
        local characterType = charData[DataFields.CharacterType]
        if characterType == Character.player then
            character:abortAction()
            local illaPlayerDeathStatus, illaPlayerDeath = pcall(require, "server.playerdeath")
            if illaPlayerDeathStatus and type(illaPlayerDeath.playerDeath) == "function" then
                illaPlayerDeath.playerDeath(character)
            end
        elseif characterType == Character.monster then
            local scriptName = charData[DataFields.Script]
            if scriptName and scriptName ~= "" then
                local status, script = xpcall(require, scriptName)
                if status and type(script.onDeath) == "function" then
                    local illaMonster = Character.fromSeleneEntity(character.SeleneEntity)
                    script.onDeath(illaMonster)
                end
            end
            local MonsterManager = require("illarion-script-loader.server.lua.lib.monsterManager")
            MonsterManager.Remove(character.SeleneEntity)
        end
    end
end

function m.GetCharacterById(id)
    local entity = Entities.findByRuntimeData(DataKeys.Character, DataFields.ID, id)
    return entity and Character.fromSeleneEntity(entity) or nil
end

function m.isGodMode(character)
    local charData = character.SeleneEntity:getRuntimeData(DataKeys.Character)
    return charData[DataFields.GodMode]
end

function m.setGodMode(character, enabled)
    local charData = character.SeleneEntity:getRuntimeData(DataKeys.Character)
    charData[DataFields.GodMode] = enabled

    local attributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")
    local attribute = attributeManager.GetAttribute(character, "hitpointsOffset")
    if enabled then
        attribute:addConstraint("godmode", function(attribute, value)
            local entity = attribute:getOwner()
            if m.isGodMode(Character.fromSeleneEntity(entity)) then
                return attribute:getValue()
            end
            return value
        end)
    else
        attribute:removeConstraint("godmode")
    end
end

return m
