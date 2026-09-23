local ObservableMapInventory = require("moonlight-inventory.server.lua.observable_map_inventory")

local IllarionInventory = ObservableMapInventory:new()

local function ItemDataTable(data)
    if type(data) == "userdata" then
        return data:toTable()
    end
    return data or {}
end

local function ItemDataEqual(left, right)
    left = ItemDataTable(left)
    right = ItemDataTable(right)
    for key, value in pairs(left) do
        if key ~= "quality" and key ~= "wear" and not tablex.deepEquals(value, right[key]) then
            return false
        end
    end
    for key in pairs(right) do
        if key ~= "quality" and key ~= "wear" and left[key] == nil then
            return false
        end
    end
    return true
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
    return itemId == otherId and ItemDataEqual(item.data, other.data)
end

function IllarionInventory:mergeItems(item, other)
    local merged = self:copyItem(item)
    self:setItemCount(merged, self:getItemCount(item) + self:getItemCount(other))
    merged.data = merged.data or {}
    local itemQuality = tonumber(item.data and item.data.quality) or 333
    local otherQuality = tonumber(other.data and other.data.quality) or 333
    local quality = math.min(math.floor(itemQuality / 100), math.floor(otherQuality / 100))
    local durability = math.min(itemQuality % 100, otherQuality % 100)
    merged.data.quality = quality * 100 + durability
    return merged
end

return IllarionInventory
