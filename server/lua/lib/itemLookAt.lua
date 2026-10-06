local illaItemLookAtOk, illaItemLookAt = pcall(require, "server.itemlookat")
local Config = require("selene.config")
local I18n = require("selene.i18n")

local m = {}
local useLegacyLookAt = Config.getProperty("useLegacyLookAt") == "true"

function m.Get(character, itemDef, item)
    local result = nil
    local scriptName = itemDef:getField("script")
    if scriptName and scriptName ~= "" then
        local status, script = xpcall(require, scriptName)
        if status and type(script.LookAtItem) == "function" then
            result = script.LookAtItem(character, item)
            if useLegacyLookAt then
                -- Legacy implementations send their tooltip through world:itemInform and intentionally return nil.
                return result
            end
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
