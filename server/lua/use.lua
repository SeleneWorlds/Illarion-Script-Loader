local Network = require("selene.network")
local Registries = require("selene.registries")
local Config = require("selene.config")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local Events = require("illarion-script-loader.server.lua.lib.events")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")

local function callUseItem(script, user, item)
    if Config.getProperty("useLegacyUseItem") == "true" then
        script.UseItem(user, item, nil, nil, nil, Action.none)
    else
        script.UseItem(user, item, Action.none)
    end
end

local function getUseItemArgs(user, item)
    if Config.getProperty("useLegacyUseItem") == "true" then
        return table.pack(user, item, nil, nil, nil)
    end
    return { user, item }
end

Network.handlePayload("illarion:use_at", function(player, payload)
    local x, y, z = PayloadValidation.coordinateInRange(player, payload, nil, 1)
    if not x then
        return
    end
    local playerEntity = player:getControlledEntity()
    local dimension = playerEntity:getDimension()
    local illaUser = Character.fromSelenePlayer(player)
    illaUser:abortAction()
    local illaPos = position(x, y, z)
    local actionData = playerEntity:getRuntimeData(DataKeys.LastAction)

    -- Entities can be either Monsters, NPCs, or non-static (dropped) items
    local entities = dimension:getEntitiesAt(x, y, z, playerEntity:getCollisionViewer())
    for i = #entities, 1, -1 do
        local entity = entities[i]
        if entity:hasTag("illarion:item") then

            local itemId = entity:getEntityDefinition():getMetadata("itemId")
            if itemId then
                local item = Registries.findByMetadata("illarion:items", "id", itemId)
                if item then
                    local scriptName = item:getField("script")
                    if scriptName then
                        local status, script = pcall(require, scriptName)
                        if status and type(script.UseItem) == "function" then
                            local illaItem = Item.fromSeleneEntity(entity)
                            actionData[DataFields.LastActionScript] = script
                            actionData[DataFields.LastActionFunction] = script.UseItem
                            actionData[DataFields.LastActionArgs] = getUseItemArgs(illaUser, illaItem)
                            callUseItem(script, illaUser, illaItem)
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
            if scriptName then
                local status, script = pcall(require, scriptName)
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
            if scriptName then
                local status, script = pcall(require, scriptName)
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

    -- Tiles can be either tiles or static items
    local tiles = dimension:getTilesAt(x, y, z, playerEntity:getCollisionViewer())
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        -- If this tile has a script metadata field, we use it as a TileScript.
        local tileScriptName = tile:getMetadata("script")
        if tileScriptName then
            local status, script = pcall(require, tileScriptName)
            if status and type(script.useTile) == "function" then
                actionData[DataFields.LastActionScript] = script
                actionData[DataFields.LastActionFunction] = script.useTile
                actionData[DataFields.LastActionArgs] = { illaUser, illaPos }
                script.useTile(illaUser, illaPos)
                return
            end
        end

        -- If this tile has an itemId metadata field, we use it as an ItemScript.
        local itemId = tile:getMetadata("itemId")
        if itemId then
            local item = Registries.findByMetadata("illarion:items", "id", itemId)
            if item then
                local scriptName = item:getField("script")
                if scriptName then
                    local status, script = pcall(require, scriptName)
                    if status and type(script.UseItem) == "function" then
                        local illaItem = Item.fromSeleneTile(tile)
                        actionData[DataFields.LastActionScript] = script
                        actionData[DataFields.LastActionFunction] = script.UseItem
                        actionData[DataFields.LastActionArgs] = getUseItemArgs(illaUser, illaItem)
                        callUseItem(script, illaUser, illaItem)
                        return
                    end
                end
            end
        end
    end
end)

Network.handlePayload("illarion:use_slot", function(player, payload)
    -- Payload is viewId, slotId
    local viewId = PayloadValidation.string(payload.viewId, 64)
    local slotId = PayloadValidation.integer(payload.slotId, 0)
    if not viewId or not slotId then
        return
    end
    local character = Character.fromSelenePlayer(player)
    character:abortAction()
    local inventory = InventoryManager.GetInventoryAtView(character, viewId)
    if not inventory then
        return
    end

    local inventoryItem = inventory:getInventoryItem(slotId)
    if inventoryItem then
        local scriptName = inventoryItem:getItem().def:getField("script")
        if scriptName then
            local status, script = pcall(require, scriptName)
            if status and type(script.UseItem) == "function" then
                callUseItem(script, character, Item.fromSeleneInventoryItem(inventoryItem))
            end
        end
    end
end)
