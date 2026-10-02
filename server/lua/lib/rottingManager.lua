local Entities = require("selene.entities")
local Players = require("selene.players")
local Registries = require("selene.registries")

local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

local m = {}

local PERMANENT_WEAR = 255

local function replacementDefinition(itemDef)
    local replacementName = itemDef:getField("objectAfterRot")
    if not replacementName then
        return nil
    end
    return Registries.findByName("illarion:items", replacementName)
end

local function initialWear(itemDef)
    return InventoryManager.InitialWear(itemDef)
end

local function nextWear(itemDef, wear, inInventory)
    if inInventory and not itemDef:getField("rotsInInventory") then
        return nil, false
    end

    wear = tonumber(wear)
    if wear == nil or wear <= 0 then
        wear = initialWear(itemDef)
    end
    if wear == PERMANENT_WEAR then
        return nil, false
    end

    wear = math.max(0, wear - 1)
    return wear, wear == 0
end

local function notifyRotOnField(entity, replacement)
    local dimension = entity:getDimension()
    local annotation = dimension:getAnnotationAt(
        entity:getCoordinate(),
        "illarion:triggerfield",
        entity:getCollisionViewer()
    )
    if not annotation or not annotation.script then
        return
    end

    local status, script = pcall(require, annotation.script)
    if status and type(script.ItemRotsOnField) == "function" then
        script.ItemRotsOnField(
            Item.fromSeleneEntity(entity),
            replacement and Item.fromSeleneEntity(replacement) or Item.fromSeleneEmpty()
        )
    end
end

function m.AgeFieldEntity(entity)
    local dimension = entity:getDimension()
    if not dimension or not entity:hasTag("illarion:item") then
        return
    end

    local itemId = entity:getEntityDefinition():getMetadata("itemId")
    local itemDef = itemId and Registries.findByMetadata("illarion:items", "id", itemId) or nil
    if not itemDef then
        return
    end

    local data = entity:getRuntimeData(DataKeys.Item)
    local wear, rotted = nextWear(itemDef, data[DataFields.Wear], false)
    if wear == nil then
        return
    end
    if not rotted then
        data[DataFields.Wear] = wear
        entity:updateVisuals()
        return
    end

    local replacement
    local replacementDef = replacementDefinition(itemDef)
    if replacementDef then
        local replacementId = replacementDef:getMetadata("id")
        local entityType = Registries.findByMetadata("entities", "itemId", replacementId)
        if not entityType then
            error("Unknown item entity for item id " .. tostring(replacementId))
        end

        replacement = Entities.create(entityType)
        local replacementData = replacement:getRuntimeData(DataKeys.Item)
        replacementData[DataFields.Count] = data[DataFields.Count] or 1
        replacementData[DataFields.Quality] = data[DataFields.Quality]
        replacementData[DataFields.Wear] = initialWear(replacementDef)
        replacementData[DataFields.Data] = data[DataFields.Data] or {}
        replacementData[DataFields.Content] = data[DataFields.Content]
        replacement:setCoordinate(entity:getCoordinate())
        replacement:spawn(dimension)
    end

    notifyRotOnField(entity, replacement)
    entity:remove()
end

local function ageInventory(inventory, seenInventories)
    if not inventory or seenInventories[inventory.data] then
        return
    end
    seenInventories[inventory.data] = true

    for _, slotId in ipairs(inventory:getSlots()) do
        local item = inventory:getItem(slotId)
        if item then
            -- Contents are aged even when the containing item itself does not rot.
            if (tonumber(item.def:getField("containerSlots")) or 0) > 0 then
                local contents = InventoryManager.GetContentsContainer({ SeleneItem = item })
                ageInventory(contents, seenInventories)
            end

            local wear, rotted = nextWear(item.def, item.wear, true)
            if wear ~= nil then
                if rotted then
                    local replacementDef = replacementDefinition(item.def)
                    if replacementDef then
                        item.def = replacementDef
                        item.wear = initialWear(replacementDef)
                        inventory:setItem(slotId, item)
                    else
                        inventory:setItem(slotId, nil)
                    end
                else
                    item.wear = wear
                    inventory:slotUpdated(slotId)
                end
            end
        end
    end
end

function m.Tick()
    local seenInventories = {}

    -- getAll returns a snapshot, so replacements can safely spawn during this pass.
    for _, entity in ipairs(Entities.getAll()) do
        if entity:hasTag("illarion:item") then
            local data = entity:getRuntimeData(DataKeys.Item)
            local itemId = entity:getEntityDefinition():getMetadata("itemId")
            local itemDef = itemId and Registries.findByMetadata("illarion:items", "id", itemId) or nil
            if data[DataFields.Content]
                    and itemDef
                    and (tonumber(itemDef:getField("containerSlots")) or 0) > 0 then
                ageInventory(InventoryManager.GetContentsContainer(Item.fromSeleneEntity(entity)), seenInventories)
            end
            m.AgeFieldEntity(entity)
        end
    end

    for _, player in ipairs(Players.getOnlinePlayers()) do
        if player:getControlledEntity() then
            local character = Character.fromSelenePlayer(player)
            local inventories = character.SeleneEntity:getRuntimeData(DataKeys.Inventories)
            for _, inventory in pairs(inventories) do
                ageInventory(inventory, seenInventories)
            end
        end
    end
end

return m
