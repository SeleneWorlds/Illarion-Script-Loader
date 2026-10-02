local ObservableMapInventory = require("moonlight-inventory.server.lua.observable_map_inventory")

local IllarionInventory = ObservableMapInventory:new()

local function initialWear(itemDef)
    return tonumber(itemDef:getField("agingSpeed")) or 255
end

function IllarionInventory:getItemMaxCount(item)
    return tonumber(item.def:getField("maxStack")) or 1
end

function IllarionInventory:getSlotMaxCount(slotId)
    return math.huge
end

function IllarionInventory:canMergeItem(item, other)
    local itemId = item.def:getMetadata("id")
    local otherId = other.def:getMetadata("id")
    return itemId == otherId and tablex.deepEquals(item.data, other.data)
end

function IllarionInventory:mergeItems(item, other)
    local merged = self:copyItem(item)
    self:setItemCount(merged, self:getItemCount(item) + self:getItemCount(other))
    local itemQuality = tonumber(item.quality) or 333
    local otherQuality = tonumber(other.quality) or 333
    local quality = math.min(math.floor(itemQuality / 100), math.floor(otherQuality / 100))
    local durability = math.min(itemQuality % 100, otherQuality % 100)
    merged.quality = quality * 100 + durability
    merged.wear = math.min(
        tonumber(item.wear) or initialWear(item.def),
        tonumber(other.wear) or initialWear(other.def)
    )
    return merged
end

return IllarionInventory
