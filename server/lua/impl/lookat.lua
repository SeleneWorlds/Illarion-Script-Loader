local Entities = require("selene.entities")
local Registries = require("selene.registries")
local Network = require("selene.network")
local I18n = require("selene.i18n")

local illaPlayerLookAt = require("server.playerlookat")
local illaItemLookAt = require("server.itemlookat")

local function LookAtItem(character, itemDef, item)
    local result = nil
    local scriptName = itemDef:GetField("script")
    if scriptName then
        local status, script = pcall(require, scriptName)
        if status and type(script.LookAtItem) == "function" then
            result = script.LookAtItem(character, item)
        end
    end
    if not result then
        result = illaItemLookAt.lookAtItem(character, item)
    end
    return result
end

Network.HandlePayload("illarion:look_at", function(player, payload)
    local entity = player.ControlledEntity
    local dimension = entity.Dimension
    local tiles = dimension:GetTilesAt(payload.x, payload.y, payload.z, entity.Vision)
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        local itemId = tile:GetMetadata("itemId")
        if itemId then
            local itemDef = Registries.FindByMetadata("illarion:items", "id", itemId)
            if not itemDef then
                error("Unknown item id " .. itemId .. " at " .. tile.Coordinate)
            end
            local result = LookAtItem(Character.fromSelenePlayer(player), itemDef, Item.fromSeleneTile(tile))
            Network.SendToPlayer(player, "illarion:look_at", {
                x = payload.x,
                y = payload.y,
                z = payload.z,
                tooltip = result
            })
        elseif tile:HasTag("illarion:tile") then
            local name = I18n.Get("tiles." .. stringx.substringAfter("illarion:", tile.Name), player.Locale) or tile.Name
            Network.SendToPlayer(player, "illarion:look_at", {
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

Network.HandlePayload("illarion:look_at_entity", function(player, payload)
    local entity = Entities.GetByNetworkId(payload.networkId)
    if entity then
        local mode = payload.mode
        local character = Character.fromSelenePlayer(player)
        local target = Character.fromSeleneEntity(entity)
        local characterType = entity.CustomData[DataKeys.CharacterType]
        if characterType == Character.player then
            illaPlayerLookAt.lookAtPlayer(character, target, mode)
        elseif characterType == Character.npc then
            local npcScript = entity.CustomData[DataKeys.NPCScript]
            if npcScript and type(npcScript.lookAtNpc) == "function" then
                npcScript.lookAtNpc(target, character, mode)
            else
                entity:SendToPlayer(player, "illarion:look_at_entity", {
                    networkId = entity.NetworkId,
                    tooltip = {
                        name = entity.Name
                    }
                })
            end
        elseif characterType == Character.monster then
            local monsterScript = entity.CustomData[DataKeys.MonsterScript]
            if monsterScript and type(monsterScript.lookAtMonster) == "function" then
                monsterScript.lookAtMonster(character, target, mode)
            end
        end
    end
end)