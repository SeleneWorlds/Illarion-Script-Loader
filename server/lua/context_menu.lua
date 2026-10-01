local Network = require("selene.network")
local Registries = require("selene.registries")

local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local ItemMovement = require("illarion-script-loader.server.lua.lib.itemMovement")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")

local menuActions = {
    lookAt = true, lookAtClose = true, open = true, use = true, useWith = true,
    pickup = true, attack = true, standDown = true, introduce = true,
    giveName = true, report = true
}

local function validTarget(player, payload, maximumRange)
    if payload.networkId == nil then
        return nil
    end
    local target = PayloadValidation.entityInRange(player, payload.networkId, maximumRange)
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
    local x, y, z = PayloadValidation.coordinateInRange(player, payload, nil, 14)
    local requestId = PayloadValidation.integer(payload.requestId, 0)
    local target = payload.networkId == nil and nil or PayloadValidation.entityInRange(player, payload.networkId, 14)
    if not x or not requestId or (payload.networkId ~= nil and not target) then
        return
    end
    payload = { x = x, y = y, z = z, networkId = payload.networkId, requestId = requestId }
    local actions = {}
    target = target and validTarget(player, payload, 14)
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
        local itemData = target and target:getRuntimeData(DataKeys.Item)
        local wear = itemData and itemData[DataFields.Wear]
        if itemDef and not ItemMovement.isImmovable(itemDef, wear) then
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
    if ItemMovement.isImmovable(itemDef, itemData[DataFields.Wear]) then
        return
    end
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
    local action = PayloadValidation.oneOf(payload.action, menuActions)
    if not action then
        return
    end
    local maximumRange = (action == "lookAt" or action == "lookAtClose" or action == "attack") and 14 or 1
    local x, y, z = PayloadValidation.coordinateInRange(player, payload, nil, maximumRange)
    local target = payload.networkId == nil and nil
        or PayloadValidation.entityInRange(player, payload.networkId, maximumRange)
    if not x or (payload.networkId ~= nil and not target) then
        return
    end
    local detail = payload.detail == nil and nil or PayloadValidation.string(payload.detail, 1000)
    if payload.detail ~= nil and not detail then
        return
    end
    payload = { x = x, y = y, z = z, networkId = payload.networkId, action = action, detail = detail }
    target = target and validTarget(player, payload, maximumRange)
    local user = Character.fromSelenePlayer(player)
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
        user.SeleneEntity:updateVisuals()
    elseif action == "giveName" and targetType == Character.player and type(payload.detail) == "string" then
        local introductions = user.SeleneEntity:getRuntimeData(DataKeys.Introductions)
        local id = targetData[DataFields.ID]
        local relationship = introductions[id] or {}
        relationship.customName = string.sub(payload.detail, 1, 50)
        introductions[id] = relationship
        target:updateVisuals()
    elseif action == "report" and targetType == Character.player and type(payload.detail) == "string" then
        user:pageGM("Report concerning " .. target:getName() .. " (" .. target:getNetworkId() .. "): " .. string.sub(payload.detail, 1, 1000))
    end
end)
