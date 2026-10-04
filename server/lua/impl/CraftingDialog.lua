local Registries = require("selene.registries")

CraftingDialog.SeleneConstructor = function(title, sfx, sfxDuration, callback)
    return {
        type = "CraftingDialog",
        title = title,
        sfx = sfx,
        sfxDuration = sfxDuration,
        callback = callback,
        groups = {},
        craftables = {}
    }
end

CraftingDialog.SeleneMethods.clearGroupsAndProducts = function(self)
    self.groups = {}
    self.craftables = {}
end

CraftingDialog.SeleneMethods.addGroup = function(name)
    table.insert(self.groups, name)
end

CraftingDialog.SeleneMethods.addCraftable = function(id, groupId, itemId, name, decisecondsToCraft, craftedStackSize)
    id = assert(tonumber(id), "id must be a number, was " .. tostring(id))
    groupId = assert(tonumber(groupId), "groupId must be a number, was " .. tostring(groupId))
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    decisecondsToCraft = assert(tonumber(decisecondsToCraft), "decisecondsToCraft must be a number, was " .. tostring(decisecondsToCraft))
    if craftedStackSize ~= nil then
        craftedStackSize = assert(tonumber(craftedStackSize), "craftedStackSize must be a number, was " .. tostring(craftedStackSize))
    end
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Unknown item id " .. itemId)
    end

    local msToCraft = decisecondsToCraft * 100
    self.craftables[id] = {
        groupId = groupId,
        itemDef = itemDef,
        name = name,
        duration = msToCraft,
        craftedStackSize = craftedStackSize or 1,
        ingredients = {}
    }
    self.lastCraftableId = id
end

CraftingDialog.SeleneMethods.addCraftableIngredient = function(itemId, number)
    itemId = assert(tonumber(itemId), "itemId must be a number, was " .. tostring(itemId))
    if number ~= nil then
        number = assert(tonumber(number), "number must be a number, was " .. tostring(number))
    end
    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        error("Unknown item id " .. itemId)
    end

    table.insert(self.craftables[self.lastCraftableId].ingredients, {
        itemDef = itemDef,
        count = number or 1
    })
end

CraftingDialog.SeleneMethods.getResult = function()
    return self.result
end

CraftingDialog.SeleneMethods.getCraftableId = function()
    return self.craftableId
end

CraftingDialog.SeleneMethods.getCraftableAmount = function(self)
    return self.craftableAmount
end

CraftingDialog.SeleneMethods.getIngredientIndex = function()
    return self.ingredientIndex
end
