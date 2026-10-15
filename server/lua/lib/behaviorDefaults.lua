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

local function itemAt(action)
    local coordinate = assert(action.data.position, "Action requires a position")
    return world:getItemOnField(position(coordinate.x, coordinate.y, coordinate.z))
end

function m.registerBehaviorDefaults(behaviors)
    behaviors:registerAction("unlock_door", function(action)
        return require("base.keys").UnlockDoor(itemAt(action))
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerAction("open_door", function(action)
        return require("base.doors").OpenDoor(itemAt(action))
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
        assert(payload.priority == nil or (type(payload.priority) == "number"
            and payload.priority == payload.priority and math.abs(payload.priority) < math.huge),
            "Inform priority must be a finite number")
        return character(context):inform(payload.message, payload.messageEnglish or payload.message, payload.priority)
    end, { type = "object", properties = {
        message = "string",
        messageEnglish = { type = "string", optional = true },
        priority = { type = "number", optional = true }
    } })

    behaviors:registerAction("decrease_movepoints", function(action, context)
        context.character.movepoints = context.character.movepoints - action.data.amount
    end, { type = "object", properties = { amount = { type = "integer", min = 0 } } })

    behaviors:registerAction("move_forward", function(_, context)
        local User = context.character
        return User:move(User:get_face_to(), false)
    end)

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
        slot = { type = "integer", min = 0, max = 11 },
        equipped = { type = "boolean", optional = true }
    } })

    return behaviors
end

function m.schema()
    return m.registerBehaviorDefaults(Behaviors:new()):schema().properties
end

return m
