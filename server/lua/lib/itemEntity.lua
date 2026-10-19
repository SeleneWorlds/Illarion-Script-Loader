local Entities = require("selene.entities")
local Registries = require("selene.registries")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local ItemMovement = require("illarion-script-loader.server.lua.lib.itemMovement")

local m = {}

function m.Create(entityDef)
    local entity = Entities.create(entityDef)
    entity:addDynamicComponent("illarion:visual", function(itemEntity)
        local itemData = itemEntity:getRuntimeData(DataKeys.Item)
        local data = itemData and itemData[DataFields.Data]
        local visual = data and data.SeleneVisual
        if not visual then
            local itemId = itemEntity:getEntityDefinition():getMetadata("itemId")
            local itemDef = itemId and Registries.findByMetadata("illarion:items", "id", itemId)
            visual = itemDef and itemDef:getField("visual")
        end
        return visual and { type = "visual", visual = visual } or nil
    end)
    entity:addDynamicComponent("illarion:draggable", function(itemEntity)
        local itemData = itemEntity:getRuntimeData(DataKeys.Item)
        local itemId = itemEntity:getEntityDefinition():getMetadata("itemId")
        local itemDef = itemId and Registries.findByMetadata("illarion:items", "id", itemId)
        return {
            type = "draggable",
            enabled = itemDef ~= nil and not ItemMovement.isImmovable(itemDef, itemData and itemData[DataFields.Wear])
        }
    end)
    entity:addDynamicComponent("illarion:item_count", function(itemEntity)
        local itemData = itemEntity:getRuntimeData(DataKeys.Item)
        local count = math.floor(tonumber(itemData and itemData[DataFields.Count]) or 1)
        return {
            type = "visual",
            visual = "illarion:labels/item_count",
            position = {
                origin = "tile_bottom_right",
                offsetX = 3,
                offsetY = -3
            },
            overrides = {
                text = count > 1 and string.format("%d", count) or ""
            }
        }
    end)
    return entity
end

return m
