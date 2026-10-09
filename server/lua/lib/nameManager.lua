local I18n = require("selene.i18n")
local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local m = {}

function m.Get(entity, viewer, locale)
    local charData = entity:getRuntimeData(DataKeys.Character)
    local characterType = charData[DataFields.CharacterType]
    if characterType == Character.player then
        if viewer == entity then return entity:getName() end
        local introductions = viewer and viewer:getRuntimeData(DataKeys.Introductions)
        local relationship = introductions and introductions[charData[DataFields.ID]]
        if relationship and relationship.customName then return "'" .. relationship.customName .. "'" end
        if relationship and relationship.introduced then return entity:getName() end
    elseif characterType ~= Character.monster then
        return entity:getName()
    end

    local race = Registries.findByMetadata("illarion:races", "id", charData[DataFields.Race])
    if race then
        local key = "nameTag." .. stringx.substringAfter(race:getName(), "illarion:")
            .. "." .. (charData[DataFields.Sex] or "male")
        if not locale then
            local listener = viewer and Character.fromSeleneEntity(viewer)
            locale = listener and listener.SelenePlayer and listener.SelenePlayer:getLocale() or "en"
        end
        return I18n.get(key, locale) or entity:getName()
    end
    return entity:getName()
end

return m
