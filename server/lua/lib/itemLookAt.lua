local illaItemLookAtOk, illaItemLookAt = pcall(require, "server.itemlookat")

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
        result = {
            name = itemDef:getField("name")
        }
    end
    return result
end

return m
