local Network = require("selene.network")
local Registries = require("selene.registries")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local ItemMovement = require("illarion-script-loader.server.lua.lib.itemMovement")

local function closeWorldContainer(item)
    for _, showcase in ipairs(InventoryManager.CloseShowcasesForWorldItem(item)) do
        Network.sendToPlayer(showcase.player, "illarion:close_showcase", { showcaseId = showcase.showcaseId })
    end
end

local function CreateItemFromEntity(entity)
    local itemId = entity:getEntityDefinition():getMetadata("itemId")
    if itemId == nil then
        return nil
    end

    local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
    if not itemDef then
        return nil
    end
    local itemData = entity:getRuntimeData(DataKeys.Item)

    return {
        def = itemDef,
        count = itemData[DataFields.Count] or 1,
        quality = itemData[DataFields.Quality],
        durability = itemData[DataFields.Durability] or 99,
        wear = itemData[DataFields.Wear],
        data = itemData[DataFields.Data] or {},
        content = itemData[DataFields.Content]
    }
end

local function CreateItemSnapshot(item)
    local data = {}
    local sourceData = item.customData
    if not sourceData and item.SeleneEntity then
        local itemData = item.SeleneEntity:getRuntimeData(DataKeys.Item)
        sourceData = itemData and itemData[DataFields.Data]
    elseif not sourceData and item.SeleneItem then
        sourceData = item.SeleneItem.data
    end
    if sourceData and type(sourceData) ~= "table" then
        sourceData = sourceData:toTable()
    end
    for key, value in pairs(sourceData or {}) do
        data[key] = value
    end

    local result = {
        id = item.id,
        pos = item.pos,
        owner = item.owner,
        itempos = item.itempos,
        inside = item.inside,
        number = item.number,
        quality = item.quality,
        wear = item.wear,
        durability = item.durability,
        isLarge = item.isLarge,
        data = item.data,
        customData = data
    }
    local itemType = item:getType()
    result.getType = function()
        return itemType
    end
    result.getData = function(self, key)
        return self.customData[key] or ""
    end
    result.setData = function(self, key, value)
        self.customData[key] = value ~= nil and tostring(value) or nil
        if key == "data" then
            self.data = tonumber(value) or 0
        end
    end
    return result
end

local function callMoveItemAfterMove(character, itemDef, sourceItem, targetItem)
    local scriptName = itemDef:getField("script")
    if not scriptName or scriptName == "" then
        return
    end

    local status, script = xpcall(require, debug.traceback, scriptName)
    if status and type(script.MoveItemAfterMove) == "function" then
        script.MoveItemAfterMove(character, sourceItem, targetItem)
    end
end

local function callMoveItemBeforeMove(character, itemDef, sourceItem, targetItem)
    local scriptName = itemDef:getField("script")
    if not scriptName or scriptName == "" then
        return true
    end

    local status, script = xpcall(require, debug.traceback, scriptName)
    if status and type(script.MoveItemBeforeMove) == "function" then
        return script.MoveItemBeforeMove(character, sourceItem, targetItem)
    end
    return true
end

local M = {}

-- Shared by manual pickup and auto-equip so movement hooks and field triggers agree.
function M.pickup(character, sourceEntity, targetInventory, toSlotId, requestedCount)
    if not targetInventory or not targetInventory:hasSlot(toSlotId) then return false end
    if not sourceEntity or ItemMovement.isOccupied(
        sourceEntity:getDimension(), sourceEntity:getCoordinate(), character.SeleneEntity
    ) then
        return false
    end

    local item = CreateItemFromEntity(sourceEntity)
    if not item or ItemMovement.isImmovable(item.def, item.wear) then
        return false
    end
    if targetInventory.isEquipment and not InventoryManager.ItemFitsEquipmentSlot(item, toSlotId) then
        return false
    end
    if targetInventory.isEquipment
            and not InventoryManager.CanEquipInHand(targetInventory, item, toSlotId) then
        return false
    end
    local sourceSnapshot = CreateItemSnapshot(Item.fromSeleneEntity(sourceEntity))
    sourceSnapshot.pos = Item.fromSeleneEntity(sourceEntity).pos
    sourceSnapshot.owner = character
    local targetScriptItem = CreateItemSnapshot(sourceSnapshot)
    targetScriptItem.pos = targetInventory.owner and targetInventory.owner.pos or character.pos
    targetScriptItem.owner = targetInventory.owner
    targetScriptItem.itempos = toSlotId
    targetScriptItem.inside = targetInventory.isContainer and Container.fromSeleneInventory(targetInventory) or nil
    targetScriptItem.getType = function()
        if targetInventory.isContainer then
            return scriptItem.container
        end
        return toSlotId < 12 and scriptItem.inventory or scriptItem.belt
    end
    if not callMoveItemBeforeMove(
        character,
        item.def,
        Item.fromSeleneEntity(sourceEntity),
        targetScriptItem
    ) then
        return false
    end
    local sourceCount = item.count
    local count = math.min(sourceCount, requestedCount)
    item.count = count
    local rest = targetInventory:addItemAt(toSlotId, item)
    local movedCount = count - rest
    if movedCount <= 0 then
        return false
    end
    InventoryManager.UpdateBlockedHand(targetInventory)
    closeWorldContainer(item)

    if movedCount < sourceCount then
        local itemData = sourceEntity:getRuntimeData(DataKeys.Item)
        itemData[DataFields.Count] = sourceCount - movedCount
        sourceEntity:updateVisuals()
    else
        local triggerfieldAnnotation = sourceEntity:getDimension():getAnnotationAt(sourceEntity:getCoordinate(), "illarion:triggerfield", sourceEntity.Collision)
        if triggerfieldAnnotation then
            local triggerfield = Registries.findByName("illarion:triggerfields", triggerfieldAnnotation.triggerfield)
            local scriptName = triggerfield and triggerfield:getField("script")
            if scriptName and scriptName ~= "" then
                local status, script = xpcall(require, debug.traceback, scriptName)
                if status and type(script.TakeItemFromField) == "function" then
                    script.TakeItemFromField(Item.fromSeleneEntity(sourceEntity), character, triggerfield)
                end
            end
        end
        sourceEntity:despawn()
    end

    callMoveItemAfterMove(
        character,
        item.def,
        sourceSnapshot,
        Item.fromSeleneInventoryItem(targetInventory:getInventoryItem(toSlotId))
    )
    return Item.fromSeleneInventoryItem(targetInventory:getInventoryItem(toSlotId))
end

M.closeWorldContainer = closeWorldContainer
M.CreateItemFromEntity = CreateItemFromEntity
M.CreateItemSnapshot = CreateItemSnapshot
M.callMoveItemBeforeMove = callMoveItemBeforeMove
M.callMoveItemAfterMove = callMoveItemAfterMove
return M
