local Registries = require("selene.registries")
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local m = {}

function m.findRaceEntity(raceId, sex)
    local preferredTypeId = sex == "female" and 1 or 0
    local fallback = nil

    for _, entityDefinition in pairs(Registries.findAll("entities")) do
        if entityDefinition:getMetadata("raceId") == raceId then
            fallback = fallback or entityDefinition
            if entityDefinition:getMetadata("typeId") == preferredTypeId then
                return entityDefinition
            end
        end
    end

    if fallback then
        return fallback
    end
    return Registries.findByName("entities", "illarion:races/race_0_0")
end

function m.GetScale(character)
    local height = AttributeManager.GetAttribute(character, "body_height"):getEffectiveValue()
    if height <= 0 then return 1 end
    local charData = character.SeleneEntity:getRuntimeData(DataKeys.Character)
    -- Monsters already store their height as a percentage, apparently
    if charData[DataFields.CharacterType] == Character.monster then
        return height / 100
    end
    local race = Registries.findByMetadata("illarion:races", "id", character:getRace())
    if not race then return 1 end
    local range = race:getField("height")
    local minimum = tonumber(range and range.min or race:getField("minHeight"))
    local maximum = tonumber(range and range.max or race:getField("maxHeight"))
    if not minimum or not maximum or maximum <= minimum then return 1 end
    local relativeHeight = math.max(0, math.min(1, (height - minimum) / (maximum - minimum)))
    return (80 + math.floor(40 * relativeHeight)) / 100
end

function m.Configure(character)
    local entity = character.SeleneEntity
    local charData = entity:getRuntimeData(DataKeys.Character)
    entity:addDynamicComponent("illarion:visual", function()
        local raceId = character:getRace()
        if charData[DataFields.CharacterType] == Character.player and AttributeManager.GetAttribute(character, "hitpoints"):getEffectiveValue() <= 0 then
            raceId = Character.ghost
        end
        return {
            type = "visual",
            visual = m.findRaceEntity(raceId, charData[DataFields.Sex] or "male"):getName(),
            scale = m.GetScale(character),
            alpha = character.isinvisible and 0.5 or 1
        }
    end)
end

return m
