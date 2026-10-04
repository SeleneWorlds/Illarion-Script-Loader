local Entities = require("selene.entities")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local m = {}

function m.Create(entityDef)
    local entity = Entities.create(entityDef)
    entity:addDynamicComponent("illarion:item_count", function(itemEntity)
        local itemData = itemEntity:getRuntimeData(DataKeys.Item)
        local count = itemData and itemData[DataFields.Count] or 1
        return {
            type = "visual",
            visual = "illarion:labels/character",
            position = {
                origin = "bottom_right"
            },
            overrides = {
                text = tostring(count)
            }
        }
    end)
    return entity
end

return m
