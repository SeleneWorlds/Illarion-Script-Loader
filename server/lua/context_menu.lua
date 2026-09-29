local Entities = require("selene.entities")
local Network = require("selene.network")
local Registries = require("selene.registries")

local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

local function validTarget(player, payload)
    local target = tonumber(payload.networkId) and Entities.getByNetworkId(payload.networkId) or nil
    if not target then
        return nil
    end
    local coordinate = target:getCoordinate()
    if coordinate:getX() ~= payload.x or coordinate:getY() ~= payload.y or coordinate:getZ() ~= payload.z then
        return nil
    end
    if target:getDimension() ~= player:getControlledEntity():getDimension() then
        return nil
    end
    return target
end

local function itemDefinition(entity)
    if not entity or not entity:hasTag("illarion:item") then
        return nil
    end
    local itemId = entity:getEntityDefinition():getMetadata("itemId")
    return itemId and Registries.findByMetadata("illarion:items", "id", itemId) or nil
end

local function staticItemDefinition(player, payload)
    local tiles = player:getControlledEntity():getDimension():getTilesAt(
        payload.x, payload.y, payload.z, player:getControlledEntity():getVisionViewer())
    for i = #tiles, 1, -1 do
        local itemId = tiles[i]:getMetadata("itemId")
        if itemId then
            return Registries.findByMetadata("illarion:items", "id", itemId), tiles[i]
        end
    end
    return nil, nil
end

Network.handlePayload("illarion:request_menu_at", function(player, payload)
    local actions = {}
    local target = validTarget(player, payload)
    local userEntity = player:getControlledEntity()
    local targetData = target and target:getRuntimeData(DataKeys.Character)
    local targetType = targetData and targetData[DataFields.CharacterType]
    if targetType then
        local isSelf = target == userEntity
        if not isSelf then
            table.insert(actions, { id = "lookAt", label = "Examine" })
            if targetType == Character.player then
                table.insert(actions, { id = "lookAtClose", label = "Examine closely" })
                table.insert(actions, { id = "giveName", label = "Give name" })
                table.insert(actions, { id = "introduce", label = "Introduce" })
            end
            local combat = userEntity:getRuntimeData(DataKeys.Combat)
            if combat and combat[DataFields.TargetId] == target:getNetworkId() then
                table.insert(actions, { id = "standDown", label = "Abort attack" })
            else
                table.insert(actions, { id = "attack", label = "Attack!" })
            end
            if targetType == Character.player then
                table.insert(actions, { id = "report", label = "Report to GM" })
            end
        end
    else
        local itemDef = itemDefinition(target)
        local tileDef, tile = staticItemDefinition(player, payload)
        local topItem = itemDef or tileDef
        if topItem and (topItem:getField("containerSlots") or 0) > 0 then
            table.insert(actions, { id = "open", label = "Open" })
        end
        table.insert(actions, { id = "lookAt", label = "Examine" })
        if itemDef then
            table.insert(actions, { id = "pickup", label = "Pick up" })
        end
        if (topItem and topItem:getField("script") and topItem:getField("script") ~= "")
                or (tile and tile:getMetadata("script")) then
            table.insert(actions, { id = "use", label = "Use" })
            table.insert(actions, { id = "useWith", label = "Use with..." })
        end
    end
    Network.sendToPlayer(player, "illarion:menu_at", {
        requestId = payload.requestId,
        actions = actions
    })
end)

local function pickup(player, payload, target)
    local itemDef = itemDefinition(target)
    if not itemDef then
        return
    end
    local itemData = target:getRuntimeData(DataKeys.Item)
    local item = {
        def = itemDef,
        count = itemData[DataFields.Count] or 1,
        quality = itemData[DataFields.Quality],
        wear = itemData[DataFields.Wear],
        data = itemData[DataFields.Data] or {}
    }
    local user = Character.fromSelenePlayer(player)
    local inventory = InventoryManager.GetBackpack(user) or InventoryManager.GetBelt(user)
    local rest = inventory:addItem(item)
    if rest == item.count then
        return
    elseif rest > 0 then
        itemData[DataFields.Count] = rest
        target:updateVisuals()
    else
        target:despawn()
    end
end

Network.handlePayload("illarion:menu_action_at", function(player, payload)
    local target = validTarget(player, payload)
    local user = Character.fromSelenePlayer(player)
    local action = payload.action
    local targetData = target and target:getRuntimeData(DataKeys.Character)
    local targetType = targetData and targetData[DataFields.CharacterType]
    if action == "lookAt" then
        Network.sendToPlayer(player, "illarion:perform_menu_action", {
            action = "lookAt", x = payload.x, y = payload.y, z = payload.z,
            networkId = target and target:getNetworkId() or nil, mode = 0
        })
    elseif action == "lookAtClose" and targetType == Character.player then
        Network.sendToPlayer(player, "illarion:perform_menu_action", {
            action = "lookAt", networkId = target:getNetworkId(), mode = 1
        })
    elseif action == "open" then
        Network.sendToPlayer(player, "illarion:perform_menu_action", {
            action = "open", x = payload.x, y = payload.y, z = payload.z
        })
    elseif action == "use" or action == "useWith" then
        Network.sendToPlayer(player, "illarion:perform_menu_action", {
            action = "use", x = payload.x, y = payload.y, z = payload.z
        })
    elseif action == "pickup" and target then
        pickup(player, payload, target)
    elseif action == "attack" and targetType and target ~= player:getControlledEntity() then
        user:abortAction()
        require("illarion-script-loader.server.lua.lib.combatManager").SetAttackTarget(user, Character.fromSeleneEntity(target))
    elseif action == "standDown" then
        user:stopAttack()
    elseif action == "introduce" and targetType == Character.player then
        Character.fromSeleneEntity(target):introduce(user)
        user.SeleneEntity:updateVisual()
    elseif action == "giveName" and targetType == Character.player and type(payload.detail) == "string" then
        local introductions = user.SeleneEntity:getRuntimeData(DataKeys.Introductions)
        local id = targetData[DataFields.ID]
        local relationship = introductions[id] or {}
        relationship.customName = string.sub(payload.detail, 1, 50)
        introductions[id] = relationship
        target:updateVisual()
    elseif action == "report" and targetType == Character.player and type(payload.detail) == "string" then
        user:pageGM("Report concerning " .. target:getName() .. " (" .. target:getNetworkId() .. "): " .. string.sub(payload.detail, 1, 1000))
    end
end)
