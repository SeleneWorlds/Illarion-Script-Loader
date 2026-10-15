local Registries = require("selene.registries")
local Behaviors = require("moonlight-behaviors.server.lua.behaviors")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

local m = {}

local function data(definition)
    assert(type(definition.data) == "table", "Behavior payload must be a table")
    return definition.data
end

local function character(context)
    return assert(context and context.character, "Behavior context requires a character")
end

local function itemAt(definition)
    local coordinate = assert(data(definition).position, "Behavior requires a position")
    return world:getItemOnField(position(coordinate.x, coordinate.y, coordinate.z))
end

function m.registerBehaviorDefaults(behaviors)
    behaviors:registerAction("unlock_door", function(action)
        return require("base.keys").UnlockDoor(itemAt(action))
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerAction("open_door", function(action)
        return require("base.doors").OpenDoor(itemAt(action))
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerAction("close_door", function(action)
        return require("base.doors").CloseDoor(itemAt(action))
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerAction("lock_door", function(action)
        return require("base.keys").LockDoor(itemAt(action))
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerAction("swap_item", function(action)
        local payload = data(action)
        assert(type(payload.oldItem) == "string", "Swap item requires an old item reference")
        local oldEntry = assert(Registries.findByName("illarion:items", payload.oldItem), "Unknown old item")
        local item = itemAt(action)
        if not item or item.id ~= oldEntry:getMetadata("id") then return false end
        local entry = assert(Registries.findByName("illarion:items", payload.item), "Unknown item")
        item.id = entry:getMetadata("id")
        return world:changeItem(item)
    end, { type = "object", properties = {
        position = "coordinate",
        oldItem = { type = "registry", registry = "illarion:items" },
        item = { type = "registry", registry = "illarion:items" }
    } })

    behaviors:registerAction("warp", function(action, context)
        local coordinate = assert(data(action).position, "Warp requires a position")
        return character(context):warp(position(coordinate.x, coordinate.y, coordinate.z))
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerAction("poison", function(action, context)
        local amount = data(action).amount
        assert(type(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge,
            "Poison amount must be a finite non-negative number")
        return character(context):increasePoisonValue(amount)
    end, { type = "object", properties = { amount = { type = "number", min = 0 } } })

    behaviors:registerAction("inform", function(action, context)
        local payload = data(action)
        assert(type(payload.message) == "string", "Inform message must be a string")
        assert(payload.messageEnglish == nil or type(payload.messageEnglish) == "string",
            "English inform message must be a string")
        return character(context):inform(payload.message, payload.messageEnglish or payload.message)
    end, { type = "object", properties = {
        message = "string",
        messageEnglish = { type = "string", optional = true }
    } })

    behaviors:registerAction("decrease_movepoints", function(action, context)
        context.character.movepoints = context.character.movepoints - action.data.amount
    end, { type = "object", properties = { amount = { type = "integer", min = 0 } } })

    behaviors:registerAction("move_forward", function(_, context)
        local User = context.character
        return User:move(User:get_face_to(), false)
    end)

    local directions = { "north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest" }
    local directionValues, validDirections = {}, {}
    for _, direction in ipairs(directions) do
        directionValues[#directionValues + 1] = { value = direction, label = direction }
        validDirections[direction] = true
    end
    behaviors:registerCondition("is_facing", function(condition, context)
        local direction = data(condition).direction
        assert(validDirections[direction], "Facing direction must be a compass direction")
        return character(context):get_face_to() == Character[direction]
    end, { type = "object", properties = {
        direction = { type = "enum", values = directionValues }
    } })

    behaviors:registerCondition("last_spoken_contains", function(condition, context)
        local payload = data(condition)
        assert(type(payload.phrase) == "string", "Last spoken phrase must be a string")
        assert(payload.ignoreCase == nil or type(payload.ignoreCase) == "boolean",
            "Ignore case must be a boolean")
        local text = character(context).lastSpokenText or ""
        local phrase = payload.phrase
        if payload.ignoreCase then
            text, phrase = text:lower(), phrase:lower()
        end
        return text:find(phrase, 1, true) ~= nil
    end, { type = "object", properties = {
        phrase = "string",
        ignoreCase = { type = "boolean", optional = true }
    } })

    behaviors:registerCondition("is_at", function(condition, context)
        local payload = data(condition)
        local subjectName = payload.subject or "character"
        assert(subjectName == "character" or subjectName == "item" or subjectName == "targetItem",
            "Position subject must be character, item, or targetItem")
        local expected = assert(payload.position, "Position condition requires a position")
        local subject = context and context[subjectName]
        local actual = subject and subject.pos
        return actual ~= nil and actual.x == expected.x and actual.y == expected.y and actual.z == expected.z
    end, { type = "object", properties = {
        position = "coordinate",
        subject = { type = "enum", optional = true, values = {
            { value = "character", label = "character" },
            { value = "item", label = "item" },
            { value = "targetItem", label = "targetItem" }
        } }
    } })

    behaviors:registerCondition("is_door_closed", function(condition)
        local item = itemAt(condition)
        return item ~= nil and require("base.doors").CheckClosedDoor(item.id)
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerCondition("is_door_locked", function(condition)
        local item = itemAt(condition)
        return item ~= nil and item.quality == 333 and require("base.doors").CheckClosedDoor(item.id)
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerCondition("is_item_at", function(condition)
        local payload = data(condition)
        assert(type(payload.item) == "string", "Item condition requires an item reference")
        local entry = assert(Registries.findByName("illarion:items", payload.item), "Unknown item")
        local item = itemAt(condition)
        return item ~= nil and item.id == entry:getMetadata("id")
    end, { type = "object", properties = {
        position = "coordinate",
        item = { type = "registry", registry = "illarion:items" }
    } })

    behaviors:registerCondition("has_item_equipped_at", function(condition, context)
        local payload = data(condition)
        local slot = payload.slot
        assert(type(slot) == "number" and slot >= 0 and slot <= 11 and slot % 1 == 0,
            "Equipment slot must be an integer from 0 to 11")
        local expected
        if payload.item ~= nil then
            assert(type(payload.item) == "string", "Equipped item must be an item reference")
            expected = assert(Registries.findByName("illarion:items", payload.item), "Unknown item")
        end
        assert(payload.data == nil or (type(payload.data) == "number"
            and payload.data == payload.data and math.abs(payload.data) < math.huge),
            "Equipped item data must be a finite number")
        local item = InventoryManager.GetEquipment(character(context)):getItem(slot)
        if item == nil or InventoryManager.IsBlockedHandItem(item) then return false end
        local numericData = tonumber(item.data and item.data.data) or 0
        return (expected == nil or item.def:getMetadata("id") == expected:getMetadata("id"))
            and (payload.data == nil or numericData == payload.data)
    end, { type = "object", properties = {
        slot = { type = "enum", values = {
            { value = 0, label = "Backpack" },
            { value = 1, label = "Head" },
            { value = 2, label = "Neck" },
            { value = 3, label = "Breast" },
            { value = 4, label = "Hands" },
            { value = 5, label = "Left hand" },
            { value = 6, label = "Right hand" },
            { value = 7, label = "Left finger" },
            { value = 8, label = "Right finger" },
            { value = 9, label = "Legs" },
            { value = 10, label = "Feet" },
            { value = 11, label = "Coat" },
        } },
        item = { type = "registry", registry = "illarion:items", optional = true },
        data = { type = "number", optional = true }
    } })

    behaviors:registerCondition("has_any_item_equipped_at", function(condition, context)
        local payload = data(condition)
        local slot = payload.slot
        assert(type(slot) == "number" and slot >= 0 and slot <= 11 and slot % 1 == 0,
            "Equipment slot must be an integer from 0 to 11")
        assert(payload.equipped == nil or type(payload.equipped) == "boolean",
            "Equipped must be a boolean")
        local item = InventoryManager.GetEquipment(character(context)):getItem(slot)
        local equipped = item ~= nil and not InventoryManager.IsBlockedHandItem(item)
        local expected = payload.equipped
        if expected == nil then expected = true end
        return equipped == expected
    end, { type = "object", properties = {
        slot = { type = "enum", values = {
            { value = 0, label = "Backpack" },
            { value = 1, label = "Head" },
            { value = 2, label = "Neck" },
            { value = 3, label = "Breast" },
            { value = 4, label = "Hands" },
            { value = 5, label = "Left hand" },
            { value = 6, label = "Right hand" },
            { value = 7, label = "Left finger" },
            { value = 8, label = "Right finger" },
            { value = 9, label = "Legs" },
            { value = 10, label = "Feet" },
            { value = 11, label = "Coat" },
        } },
        equipped = { type = "boolean", optional = true }
    } })

    return behaviors
end

function m.schema()
    return m.registerBehaviorDefaults(Behaviors:new()):schema().properties
end

return m
