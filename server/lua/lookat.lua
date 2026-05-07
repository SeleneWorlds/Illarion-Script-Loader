local Entities = require("selene.entities")
local Registries = require("selene.registries")
local Network = require("selene.network")
local I18n = require("selene.i18n")

local illaPlayerLookAt = require("server.playerlookat")
local ok, illaItemLookAt = pcall(require, "server.itemlookat")

local function LookAtItem(character, itemDef, item)
    local result = nil
    local scriptName = itemDef:getField("script")
    if scriptName then
        local status, script = pcall(require, scriptName)
        if status and type(script.LookAtItem) == "function" then
            result = script.LookAtItem(character, item)
        end
    end
    if not result and illaItemLookAt then
        result = illaItemLookAt.lookAtItem(character, item)
    end
    return result
end

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
            local result = LookAtItem(Character.fromSelenePlayer(player), itemDef, Item.fromSeleneTile(tile))
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
        local mode = payload.mode
        local character = Character.fromSelenePlayer(player)
        local target = Character.fromSeleneEntity(entity)
        local charData = entity:getRuntimeData(DataKeys.Character)
        local characterType = charData[DataFields.CharacterType]
        if characterType == Character.player then
            illaPlayerLookAt.lookAtPlayer(character, target, mode)
        elseif characterType == Character.npc then
            local status, script = pcall(require, charData[DataFields.Script])
            if status and type(script.lookAtNpc) == "function" then
                script.lookAtNpc(target, character, mode)
            else
                entity:sendToPlayer(player, "illarion:look_at_entity", {
                    networkId = entity.NetworkId,
                    tooltip = {
                        name = entity:getName()
                    }
                })
            end
        elseif characterType == Character.monster then
            local status, script = pcall(require, charData[DataFields.Script])
            if status and type(script.lookAtMonster) == "function" then
                script.lookAtMonster(character, target, mode)
            end
        end
    end
end)