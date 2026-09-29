local Network = require("selene.network")
local Config = require("selene.config")

local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

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

local function openShowcase(player, character, inventory)
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
    InventoryManager.SetShowcase(character, showcaseId, inventory, token)
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
    local character = Character.fromSelenePlayer(player)
    character:abortAction()
    local playerEntity = player:getControlledEntity()
    local dimension = playerEntity:getDimension()
    local entities = dimension:getEntitiesAt(payload.x, payload.y, payload.z, playerEntity:getCollisionViewer())
    for i = #entities, 1, -1 do
        local entity = entities[i]
        if entity:hasTag("illarion:item") then
            -- TODO entity items
        end
    end
    local tiles = dimension:getTilesAt(payload.x, payload.y, payload.z, playerEntity:getCollisionViewer())
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        local itemId = tile:getMetadata("itemId")
        if itemId then
            local isDepot = itemId == 321 or itemId == 4817
            local item = Item.fromSeleneTile(tile)
            if isDepot then
                if illaDepot.onOpenDepot(character, item) then
                    local inventory = InventoryManager.GetDepot(character, tonumber(item:getData("depot")) or 0)
                    openShowcase(player, character, inventory)
                end
            else
                local inventory = InventoryManager.GetContentsContainer(item)
                openShowcase(player, character, inventory)
            end
        end
    end
end)

Network.handlePayload("illarion:open_container_slot", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    character:abortAction()
    local inventory = InventoryManager.GetInventoryAtView(character, payload.viewId)
    if not inventory then
        return
    end

    local inventoryItem = inventory:getInventoryItem(payload.slotId)
    if inventoryItem then
        local contents = InventoryManager.GetContentsContainer(Item.fromSeleneInventoryItem(inventoryItem))
        openShowcase(player, character, contents)
    end
end)

Network.handlePayload("illarion:close_showcase", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local showcaseId = math.tointeger(tonumber(payload.showcaseId))
    if showcaseId and showcaseId >= 0 and showcaseId < maxShowcases then
        InventoryManager.CloseShowcase(character, showcaseId)
    end
end)
