local Network = require("selene.network")
local Registries = require("selene.registries")
local Config = require("selene.config")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local Events = require("illarion-script-loader.server.lua.lib.events")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")

local function callUseItem(script, user, item, targetItem, counter)
    if Config.getProperty("useLegacyUseItem") == "true" then
        script.UseItem(user, item, targetItem, counter, 0, Action.none)
    else
        script.UseItem(user, item, Action.none)
    end
end

local function getUseItemArgs(user, item, targetItem, counter)
    if Config.getProperty("useLegacyUseItem") == "true" then
        return { user, item, targetItem, counter, 0 }
    end
    return { user, item }
end

Network.handlePayload("illarion:use_at", function(player, payload)
    local x, y, z = PayloadValidation.coordinateInRange(player, payload, nil, 1)
    local counter = PayloadValidation.integer(payload.count, 1, 250)
    if not x or not counter then
        return
    end
    local playerEntity = player:getControlledEntity()
    local dimension = playerEntity:getDimension()
    local illaUser = Character.fromSelenePlayer(player)
    illaUser:abortAction()
    local illaPos = position(x, y, z)
    local actionData = playerEntity:getRuntimeData(DataKeys.LastAction)

    -- Entities can be either Monsters, NPCs, or non-static (dropped) items
    local entities = dimension:getEntitiesAt(x, y, z, playerEntity:getInteractionViewer())
    for i = #entities, 1, -1 do
        local entity = entities[i]
        if entity:hasTag("illarion:item") then
            local itemId = entity:getEntityDefinition():getMetadata("itemId")
            if itemId then
                local item = Registries.findByMetadata("illarion:items", "id", itemId)
                if item then
                    local scriptName = item:getField("script")
                    if scriptName and scriptName ~= "" then
                        local status, script = xpcall(require, scriptName)
                        if status and type(script.UseItem) == "function" then
                            local illaItem = Item.fromSeleneEntity(entity)
                            actionData[DataFields.LastActionScript] = script
                            actionData[DataFields.LastActionFunction] = script.UseItem
                            local targetItem = Item.fromSeleneEmpty()
                            actionData[DataFields.LastActionArgs] = getUseItemArgs(illaUser, illaItem, targetItem, counter)
                            callUseItem(script, illaUser, illaItem, targetItem, counter)
                            return
                        end
                    end
                end
            end
        end

        local charData = entity:getRuntimeData(DataKeys.Character)
        local characterType = charData and charData[DataFields.CharacterType]
        if characterType == Character.monster then
            local scriptName = charData[DataFields.Script]
            if scriptName and scriptName ~= "" then
                local status, script = xpcall(require, scriptName)
                if status and type(script.useMonster) == "function" then
                    actionData[DataFields.LastActionScript] = script
                    actionData[DataFields.LastActionFunction] = script.useMonster
                    actionData[DataFields.LastActionArgs] = { illaUser, illaPos }
                    script.useMonster(illaUser, illaPos)
                    return
                end
            end
        elseif characterType == Character.npc then
            local event = { cancel = false }
            Events.onUseNpc:fire(event, entity, player)
            if event.cancel then
                return
            end

            local scriptName = charData[DataFields.Script]
            if scriptName and scriptName ~= "" then
                local status, script = xpcall(require, scriptName)
                if status and type(script.useNPC) == "function" then
                    local illaNpc = Character.fromSeleneEntity(entity)
                    actionData[DataFields.LastActionScript] = script
                    actionData[DataFields.LastActionFunction] = script.useNPC
                    actionData[DataFields.LastActionArgs] = { illaNpc, illaUser }
                    script.useNPC(illaNpc, illaUser)
                    return
                end
            end
        end
    end

    -- Static items take precedence over the base tile.
    local tiles = dimension:getTilesAt(x, y, z, playerEntity:getInteractionViewer())
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        local itemId = tile:getMetadata("itemId")
        if itemId then
            local item = Registries.findByMetadata("illarion:items", "id", itemId)
            if item then
                local scriptName = item:getField("script")
                if scriptName and scriptName ~= "" then
                    local status, script = xpcall(require, scriptName)
                    if status and type(script.UseItem) == "function" then
                        local illaItem = Item.fromSeleneTile(tile)
                        actionData[DataFields.LastActionScript] = script
                        actionData[DataFields.LastActionFunction] = script.UseItem
                        local targetItem = Item.fromSeleneEmpty()
                        actionData[DataFields.LastActionArgs] = getUseItemArgs(illaUser, illaItem, targetItem, counter)
                        callUseItem(script, illaUser, illaItem, targetItem, counter)
                        return
                    end
                end
            end
            -- As with entity items, a static item without a use script still
            -- covers the base tile.
            return
        end
    end

    -- With no items on top, use the base tile's TileScript.
    local tile = tiles[1]
    local tileScriptName = tile and tile:getMetadata("script")
    if tileScriptName then
        local status, script = xpcall(require, tileScriptName)
        if status and type(script.useTile) == "function" then
            actionData[DataFields.LastActionScript] = script
            actionData[DataFields.LastActionFunction] = script.useTile
            actionData[DataFields.LastActionArgs] = { illaUser, illaPos }
            script.useTile(illaUser, illaPos)
        end
    end
end)

Network.handlePayload("illarion:use_slot", function(player, payload)
    -- Payload is viewId, slotId, optional targetViewId and targetSlotId, count
    local viewId = PayloadValidation.string(payload.viewId, 64)
    local slotId = PayloadValidation.integer(payload.slotId, 0)
    local counter = PayloadValidation.integer(payload.count, 1, 250)
    if not viewId or not slotId or not counter then
        return
    end
    local character = Character.fromSelenePlayer(player)
    character:abortAction()
    local actionData = character.SeleneEntity:getRuntimeData(DataKeys.LastAction)
    local inventory = InventoryManager.GetInventoryAtView(character, viewId)
    if not inventory then
        return
    end

    local inventoryItem = inventory:getInventoryItem(slotId)
    if inventoryItem then
        local targetItem = Item.fromSeleneEmpty()
        if payload.targetViewId ~= nil or payload.targetSlotId ~= nil then
            local targetViewId = PayloadValidation.string(payload.targetViewId, 64)
            local targetSlotId = PayloadValidation.integer(payload.targetSlotId, 0)
            if not targetViewId or not targetSlotId then
                return
            end
            local targetInventory = InventoryManager.GetInventoryAtView(character, targetViewId)
            if not targetInventory then
                return
            end
            local targetInventoryItem = targetInventory:getInventoryItem(targetSlotId)
            if not targetInventoryItem then
                return
            end
            targetItem = Item.fromSeleneInventoryItem(targetInventoryItem)
        end
        local scriptName = inventoryItem:getItem().def:getField("script")
        if scriptName and scriptName ~= "" then
            local status, script = xpcall(require, scriptName)
            if status and type(script.UseItem) == "function" then
                local item = Item.fromSeleneInventoryItem(inventoryItem)
                actionData[DataFields.LastActionScript] = script
                actionData[DataFields.LastActionFunction] = script.UseItem
                actionData[DataFields.LastActionArgs] = getUseItemArgs(character, item, targetItem, counter)
                callUseItem(script, character, item, targetItem, counter)
            end
        end
    end
end)

Network.handlePayload("illarion:use_slot_at", function(player, payload)
    local viewId = PayloadValidation.string(payload.viewId, 64)
    local slotId = PayloadValidation.integer(payload.slotId, 0)
    local x, y, z = PayloadValidation.coordinateInRange(player, payload, nil, 1)
    local counter = PayloadValidation.integer(payload.count, 1, 250)
    if not viewId or not slotId or not x or not counter then
        return
    end

    local character = Character.fromSelenePlayer(player)
    character:abortAction()
    local inventory = InventoryManager.GetInventoryAtView(character, viewId)
    if not inventory then
        return
    end

    local inventoryItem = inventory:getInventoryItem(slotId)
    if not inventoryItem then
        return
    end

    local scriptName = inventoryItem:getItem().def:getField("script")
    if not scriptName then
        return
    end

    local status, script = xpcall(require, scriptName)
    if not status or type(script.UseItemWithField) ~= "function" then
        return
    end

    local item = Item.fromSeleneInventoryItem(inventoryItem)
    local targetPosition = position(x, y, z)
    local actionData = character.SeleneEntity:getRuntimeData(DataKeys.LastAction)
    actionData[DataFields.LastActionScript] = script
    actionData[DataFields.LastActionFunction] = script.UseItemWithField
    actionData[DataFields.LastActionArgs] = { character, item, targetPosition, counter, 0 }
    script.UseItemWithField(character, item, targetPosition, counter, 0, Action.none)
end)
