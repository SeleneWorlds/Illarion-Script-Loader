local Registries = require("selene.registries")
local Network = require("selene.network")
local I18n = require("selene.i18n")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local NameManager = require("illarion-script-loader.server.lua.lib.nameManager")
local Events = require("illarion-script-loader.server.lua.lib.events")
local ItemLookAt = require("illarion-script-loader.server.lua.lib.itemLookAt")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")
local illaPlayerLookAt = require("server.playerlookat")

Network.handlePayload("illarion:look_at", function(player, payload)
    local x, y, z = PayloadValidation.coordinateInRange(player, payload, nil, 14)
    if not x then
        return
    end
    local entity = player:getControlledEntity()
    local dimension = entity:getDimension()
    local tiles = dimension:getTilesAt(x, y, z, entity:getVisionViewer())
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        local itemId = tile:getMetadata("itemId")
        if itemId then
            local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
            if not itemDef then
                error("Unknown item id " .. itemId .. " at " .. tile:getCoordinate())
            end
            local result = ItemLookAt.Get(Character.fromSelenePlayer(player), itemDef, Item.fromSeleneTile(tile))
            if result then
                Network.sendToPlayer(player, "illarion:look_at", {
                    x = x, y = y, z = z,
                    tooltip = result
                })
            end
            return
        elseif tile:hasTag("illarion:tile") then
            local name = I18n.get("tiles." .. stringx.substringAfter(tile:getName(), "illarion:"), player:getLocale()) or tile:getName()
            Network.sendToPlayer(player, "illarion:look_at", {
                x = x, y = y, z = z,
                tooltip = {
                    name = name
                }
            })
            return
        end
    end
end)

Network.handlePayload("illarion:look_at_entity", function(player, payload)
    local mode = payload.mode == nil and 0 or PayloadValidation.integer(payload.mode, 0, 1)
    if mode == nil then
        return
    end
    local entity = PayloadValidation.entityInRange(player, payload.networkId, 14)
    if entity then
        local character = Character.fromSelenePlayer(player)
        if entity:hasTag("illarion:item") then
            local itemId = entity:getEntityDefinition():getMetadata("itemId")
            if itemId then
                local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
                if not itemDef then
                    error("Unknown item id " .. itemId .. " on entity " .. entity:getName())
                end
                local result = ItemLookAt.Get(character, itemDef, Item.fromSeleneEntity(entity))
                if result then
                    Network.sendToPlayer(player, "illarion:look_at_entity", {
                        networkId = entity:getNetworkId(),
                        tooltip = result
                    })
                end
            end
            return
        end

        local charData = entity:getRuntimeData(DataKeys.Character)
        local characterType = charData and charData[DataFields.CharacterType]
        if not characterType or entity:getDimension() ~= player:getControlledEntity():getDimension() then
            return
        end
        local target = Character.fromSeleneEntity(entity)
        if characterType == Character.player then
            illaPlayerLookAt.lookAtPlayer(character, target, mode)
        elseif characterType == Character.npc then
            local event = { cancel = false }
            Events.onLookAtNpc:fire(event, entity, player)
            if not event.cancel then
                local scriptName = charData[DataFields.Script]
                if scriptName and scriptName ~= nil then
                    local status, script = xpcall(require, scriptName)
                    if status and type(script.lookAtNpc) == "function" then
                        script.lookAtNpc(target, character, mode)
                        return
                    end
                end
                Network.sendToPlayer(player, "illarion:look_at_entity", {
                    networkId = entity:getNetworkId(),
                    tooltip = {
                        name = NameManager.Get(entity, player:getControlledEntity(), player:getLocale())
                    }
                })
            end
        elseif characterType == Character.monster then
            local status, script = xpcall(require, charData[DataFields.Script])
            if status and type(script.lookAtMonster) == "function" then
                script.lookAtMonster(character, target, mode)
            else
                Network.sendToPlayer(player, "illarion:look_at_entity", {
                    networkId = entity:getNetworkId(),
                    tooltip = {
                        name = NameManager.Get(entity, player:getControlledEntity(), player:getLocale())
                    }
                })
            end
        end
    end
end)

Network.handlePayload("illarion:look_at_slot", function(player, payload)
    local viewId = PayloadValidation.string(payload.viewId, 64)
    local slotId = PayloadValidation.integer(payload.slotId, 0)
    if not viewId or not slotId then
        return
    end
    local character = Character.fromSelenePlayer(player)
    local inventory = require("illarion-script-loader.server.lua.lib.inventoryManager").GetInventoryAtView(character, viewId)
    local inventoryItem = inventory and inventory:getInventoryItem(slotId)
    if not inventoryItem then
        return
    end

    local item = inventoryItem:getItem()
    local result = ItemLookAt.Get(character, item.def, Item.fromSeleneInventoryItem(inventoryItem))
    if result then
        Network.sendToPlayer(player, "illarion:look_at_slot", {
            viewId = viewId,
            slotId = slotId,
            tooltip = result
        })
    end
end)
