local illaItemLookAtOk, illaItemLookAt = pcall(require, "server.itemlookat")
local I18n = require("selene.i18n")

local m = {}

function m.Get(character, itemDef, item)
    local result = nil
    local scriptName = itemDef:getField("script")
    if scriptName then
        local status, script = pcall(require, scriptName)
        if status and type(script.LookAtItem) == "function" then
            result = script.LookAtItem(character, item)
        end
    end
    if not result and illaItemLookAtOk then
        result = illaItemLookAt.lookAtItem(character, item)
    end
    if not result then
        local locale = character:getPlayerLanguage() == Player.german and "de" or "en"
        local key = "item." .. stringx.substringAfter(itemDef:getName(), "illarion:")
        result = {
            name = I18n.get(key, locale) or itemDef:getField("name") or itemDef:getName()
        }
    end
    return result
end

return m
