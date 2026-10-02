local Network = require("selene.network")
local Config = require("selene.config")
local Entities = require("selene.entities")

local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")

local illaDepot = require("server.depot")

local configuredMaxShowcases = math.floor(tonumber(Config.getProperty("maxShowcases", "2")) or 2)
local maxShowcases = math.max(1, math.min(256, configuredMaxShowcases))
local nextShowcaseToken = 0

local function sendShowcase(player, showcaseId, inventory)
    local viewId = "showcase:" .. showcaseId
    Network.sendToPlayer(player, "illarion:showcase", {
        viewId = viewId,
        slotCount = #inventory:getSlots()
    })
    for _, slotId in ipairs(inventory:getSlots()) do
        local item = inventory:getItem(slotId)
        Network.sendToPlayer(player, "illarion:update_slot", {
            viewId = viewId,
            slotId = slotId,
            item = InventoryManager.SerializeItem(item)
        })
    end
end

local function openShowcase(player, character, inventory, origin)
    if not inventory then
        return
    end

    local showcaseId, existing = InventoryManager.FindShowcase(character, inventory)
    if existing then
        sendShowcase(player, showcaseId, inventory)
        return
    end

    local showcases = InventoryManager.GetShowcases(character)
    for candidate = 0, maxShowcases - 1 do
        if not showcases[candidate] then
            showcaseId = candidate
            break
        end
    end
    -- Reuse the first showcase when the client's capacity is exhausted.
    showcaseId = showcaseId or 0

    nextShowcaseToken = nextShowcaseToken + 1
    local token = nextShowcaseToken
    InventoryManager.SetShowcase(character, showcaseId, inventory, token, origin)
    inventory:subscribe(function(data)
        local current = InventoryManager.GetShowcases(character)[showcaseId]
        if not current or current.token ~= token then
            return
        end
        local slotId = data.dirtySlot
        if slotId then
            Network.sendToPlayer(player, "illarion:update_slot", {
                viewId = "showcase:" .. showcaseId,
                slotId = slotId,
                item = InventoryManager.SerializeItem(inventory:getItem(slotId))
            })
        end
    end)
    sendShowcase(player, showcaseId, inventory)
end

Network.handlePayload("illarion:open_container_at", function(player, payload)
    local x, y, z = PayloadValidation.coordinateInRange(player, payload, nil, 1)
    if not x then
        return
    end
    local character = Character.fromSelenePlayer(player)
    character:abortAction()
    local playerEntity = player:getControlledEntity()
    local dimension = playerEntity:getDimension()
    local entities = dimension:getEntitiesAt(x, y, z, playerEntity:getCollisionViewer())
    for i = #entities, 1, -1 do
        local entity = entities[i]
        if entity:hasTag("illarion:item") then
            local inventory = InventoryManager.GetContentsContainer(Item.fromSeleneEntity(entity))
            if inventory then
                openShowcase(player, character, inventory, { x = x, y = y, z = z })
                return
            end
        end
    end
    local tiles = dimension:getTilesAt(x, y, z, playerEntity:getCollisionViewer())
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        local itemId = tile:getMetadata("itemId")
        if itemId then
            local isDepot = itemId == 321 or itemId == 4817
            local item = Item.fromSeleneTile(tile)
            if isDepot then
                if illaDepot.onOpenDepot(character, item) then
                    local inventory = InventoryManager.GetDepot(character, tonumber(item:getData("depot")) or 0)
                    openShowcase(player, character, inventory, { x = x, y = y, z = z })
                end
            else
                local inventory = InventoryManager.GetContentsContainer(item)
                openShowcase(player, character, inventory, { x = x, y = y, z = z })
            end
        end
    end
end)

Network.handlePayload("illarion:open_container_slot", function(player, payload)
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
        local contents = InventoryManager.GetContentsContainer(Item.fromSeleneInventoryItem(inventoryItem))
        local origin
        local showcaseId = type(viewId) == "string" and tonumber(stringx.removePrefix(viewId, "showcase:"))
        local parentShowcase = showcaseId and InventoryManager.GetShowcases(character)[showcaseId]
        if parentShowcase then
            origin = parentShowcase.origin
        end
        openShowcase(player, character, contents, origin)
    end
end)

Entities.steppedOnTile:connect(function(entity, coordinate)
    local character = Character.fromSeleneEntity(entity)
    local showcases = InventoryManager.GetShowcases(character)
    if not showcases then
        return
    end

    for showcaseId, showcase in pairs(showcases) do
        local origin = showcase.origin
        if origin and (coordinate:getZ() ~= origin.z
                or math.abs(coordinate:getX() - origin.x) > 1
                or math.abs(coordinate:getY() - origin.y) > 1) then
            InventoryManager.CloseShowcase(character, showcaseId)
            Network.sendToEntity(entity, "illarion:close_showcase", { showcaseId = showcaseId })
        end
    end
end)

Network.handlePayload("illarion:close_showcase", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local showcaseId = PayloadValidation.integer(payload.showcaseId, 0, maxShowcases - 1)
    if showcaseId and showcaseId >= 0 and showcaseId < maxShowcases then
        InventoryManager.CloseShowcase(character, showcaseId)
    end
end)
