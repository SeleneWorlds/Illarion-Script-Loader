local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

local m = {}

local function inventoryWeight(inventory, seen)
    if not inventory then return 0 end
    local weight = 0
    for _, slot in ipairs(inventory:getSlots()) do
        local item = inventory:getItem(slot)
        if item then
            weight = weight + (tonumber(item.def:getField("weight")) or 0) * inventory:getItemCount(item)
            if item.content and not seen[item.content] then
                seen[item.content] = true
                weight = weight + inventoryWeight(InventoryManager.GetContentsContainer({SeleneItem = item}), seen)
            end
        end
    end
    return weight
end

-- Character stats modify move duration for players, NPCs and monsters.
function m.GetMultiplier(character)
    local agility = math.min(character:increaseAttrib("agility", 0), 20)
    local seen = {}
    local weight = inventoryWeight(InventoryManager.GetEquipment(character), seen)
        + inventoryWeight(InventoryManager.GetBelt(character), seen)
    local capacity = character:increaseAttrib("strength", 0) * 500 + 5000
    local load = math.max(0, math.min(30000, weight)) / math.max(1, capacity)
    local speed = character.speed
    if speed <= 0 then speed = 1 end
    return (1 + (10 - agility) * 0.01 + load * 0.3) / speed
end

function m.Configure(character)
    local entity = character.SeleneEntity
    local attribute = entity:getAttribute("selene:movement_duration_multiplier")
        or entity:createAttribute("selene:movement_duration_multiplier", 1)
    attribute:addModifier("illarion", function(_, value)
        return value * m.GetMultiplier(character)
    end)
end

return m
