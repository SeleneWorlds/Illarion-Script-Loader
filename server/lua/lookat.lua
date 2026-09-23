local Entities = require("selene.entities")
local Registries = require("selene.registries")
local Network = require("selene.network")
local I18n = require("selene.i18n")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local Events = require("illarion-script-loader.server.lua.lib.events")
local ItemLookAt = require("illarion-script-loader.server.lua.lib.itemLookAt")
local illaPlayerLookAt = require("server.playerlookat")

Network.handlePayload("illarion:look_at", function(player, payload)
    local entity = player:getControlledEntity()
    local dimension = entity:getDimension()
    local tiles = dimension:getTilesAt(payload.x, payload.y, payload.z, entity:getVisionViewer())
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        local itemId = tile:getMetadata("itemId")
        if itemId then
            local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
            if not itemDef then
                error("Unknown item id " .. itemId .. " at " .. tile:getCoordinate())
            end
            local result = ItemLookAt.Get(Character.fromSelenePlayer(player), itemDef, Item.fromSeleneTile(tile))
            Network.sendToPlayer(player, "illarion:look_at", {
                x = payload.x,
                y = payload.y,
                z = payload.z,
                tooltip = result
            })
        elseif tile:hasTag("illarion:tile") then
            local name = I18n.get("tiles." .. stringx.substringAfter("illarion:", tile:getName()), player:getLocale()) or tile:getName()
            Network.sendToPlayer(player, "illarion:look_at", {
                x = payload.x,
                y = payload.y,
                z = payload.z,
                tooltip = {
                    name = name
                }
            })
            return
        end
    end
end)

Network.handlePayload("illarion:look_at_entity", function(player, payload)
    local entity = Entities.getByNetworkId(payload.networkId)
    if entity then
        local mode = payload.mode or 0
        local character = Character.fromSelenePlayer(player)
        if entity:hasTag("illarion:item") then
            local itemId = entity:getEntityDefinition():getMetadata("itemId")
            if itemId then
                local itemDef = Registries.findByMetadata("illarion:items", "id", itemId)
                if not itemDef then
                    error("Unknown item id " .. itemId .. " on entity " .. entity:getName())
                end
                Network.sendToPlayer(player, "illarion:look_at_entity", {
                    networkId = entity:getNetworkId(),
                    tooltip = ItemLookAt.Get(character, itemDef, Item.fromSeleneEntity(entity))
                })
            end
            return
        end

        local target = Character.fromSeleneEntity(entity)
        local charData = entity:getRuntimeData(DataKeys.Character)
        local characterType = charData and charData[DataFields.CharacterType]
        if characterType == Character.player then
            illaPlayerLookAt.lookAtPlayer(character, target, mode)
        elseif characterType == Character.npc then
            local event = { cancel = false }
            Events.onLookAtNpc:fire(event, entity, player)
            if not event.cancel then
                local status, script = pcall(require, charData[DataFields.Script])
                if status and type(script.lookAtNpc) == "function" then
                    script.lookAtNpc(target, character, mode)
                else
                    Network.sendToPlayer(player, "illarion:look_at_entity", {
                        networkId = entity:getNetworkId(),
                        tooltip = {
                            name = entity:getName()
                        }
                    })
                end
            end
        elseif characterType == Character.monster then
            local status, script = pcall(require, charData[DataFields.Script])
            if status and type(script.lookAtMonster) == "function" then
                script.lookAtMonster(character, target, mode)
            end
        end
    end
end)

Network.handlePayload("illarion:look_at_slot", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local inventory = require("illarion-script-loader.server.lua.lib.inventoryManager").GetInventoryAtView(character, payload.viewId)
    local inventoryItem = inventory and inventory:getInventoryItem(payload.slotId)
    if not inventoryItem then
        return
    end

    local item = inventoryItem:getItem()
    Network.sendToPlayer(player, "illarion:look_at_slot", {
        viewId = payload.viewId,
        slotId = payload.slotId,
        tooltip = ItemLookAt.Get(character, item.def, Item.fromSeleneInventoryItem(inventoryItem))
    })
end)
