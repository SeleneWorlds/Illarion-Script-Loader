local ObservableMapInventory = require("moonlight-inventory.server.lua.observable_map_inventory")
local Config = require("selene.config")

local IllarionInventory = ObservableMapInventory:new()
local useLegacyContainerCompaction = Config.getProperty("useLegacyContainerCompaction") == "true"

local function firstFreeSlot(inventory)
    for _, slotId in ipairs(inventory:getSlots()) do
        if inventory:getItem(slotId) == nil then
            return slotId
        end
    end
end

function IllarionInventory:addItemAt(slotId, item)
    if useLegacyContainerCompaction and self.isContainer then
        slotId = firstFreeSlot(self)
        if slotId == nil then
            return self:getItemCount(item)
        end
    end
    return ObservableMapInventory.addItemAt(self, slotId, item)
end

function IllarionInventory:moveItemTo(targetInventory, fromSlotId, toSlotId, count, context)
    if targetInventory ~= self and useLegacyContainerCompaction and targetInventory.isContainer then
        toSlotId = firstFreeSlot(targetInventory)
        if toSlotId == nil then
            return false
        end
    end
    return ObservableMapInventory.moveItemTo(self, targetInventory, fromSlotId, toSlotId, count, context)
end

function IllarionInventory:removeItem(filter, amount)
    if not useLegacyContainerCompaction or not self.isContainer then
        return ObservableMapInventory.removeItem(self, filter, amount)
    end

    local rest = amount
    local slots = self:getSlots()
    local slotIndex = 1
    while slotIndex <= #slots do
        local slotId = slots[slotIndex]
        local item = self:getItem(slotId)
        if item and filter(item) then
            local itemCount = self:getItemCount(item)
            local toRemove = math.min(rest, itemCount)
            if toRemove >= itemCount then
                self:setItem(slotId, nil)
                rest = rest - itemCount
            else
                self:setItemCount(item, itemCount - toRemove)
                self:slotUpdated(slotId)
                rest = rest - toRemove
                slotIndex = slotIndex + 1
            end
            if rest <= 0 then
                return 0
            end
        else
            slotIndex = slotIndex + 1
        end
    end
    return rest
end

function IllarionInventory:setItem(slotId, item)
    ObservableMapInventory.setItem(self, slotId, item)
    if item ~= nil or not useLegacyContainerCompaction or not self.isContainer then
        return
    end

    local emptySlotId = slotId
    local foundEmptySlot = false
    for _, candidateSlotId in ipairs(self:getSlots()) do
        if candidateSlotId == emptySlotId then
            foundEmptySlot = true
        elseif foundEmptySlot then
            local candidateItem = self:getItem(candidateSlotId)
            if candidateItem ~= nil then
                ObservableMapInventory.setItem(self, emptySlotId, candidateItem)
                ObservableMapInventory.setItem(self, candidateSlotId, nil)
                emptySlotId = candidateSlotId
            end
        end
    end
end

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
