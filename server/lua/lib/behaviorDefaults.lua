local Registries = require("selene.registries")
local Dimensions = require("selene.dimensions")
local Behaviors = require("moonlight-behaviors.server.lua.behaviors")
local Rolls = require("moonlight-rolls.server.lua.rolls")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")

local m = {}

local function data(definition)
    assert(type(definition.data) == "table", "Behavior payload must be a table")
    return definition.data
end

local function character(context)
    return assert(context and context.character, "Behavior context requires a character")
end

local function targetPosition(payload, context)
    local coordinate = payload.position
    if coordinate == nil then return character(context).pos end
    assert(type(coordinate) == "table", "Position must be a coordinate")
    for _, axis in ipairs({ "x", "y", "z" }) do
        local value = coordinate[axis]
        assert(type(value) == "number" and math.abs(value) < math.huge and value % 1 == 0,
            "Coordinate components must be finite integers")
    end
    return position(coordinate.x, coordinate.y, coordinate.z)
end

local function monsterId(reference)
    assert(type(reference) == "string", "Monster requires a registry reference")
    local entry = assert(Registries.findByName("illarion:monsters", reference), "Unknown monster: " .. reference)
    return entry:getMetadata("id")
end

-- Numeric values may be constants or expressions evaluated when the behavior runs.
local function numericValue(value, depth)
    depth = depth or 0
    assert(depth < 16, "Numeric expression is too deeply nested")
    local result
    if type(value) == "number" then
        result = value
    else
        assert(type(value) == "table", "Expected a number or numeric expression")
        if value.type == "world_time" then
            local units = { year=true, month=true, day=true, hour=true, minute=true,
                second=true, unix=true, illarion=true }
            assert(units[value.unit], "Unknown world time unit")
            result = world:getTime(value.unit)
        elseif value.type == "add" then
            result = numericValue(value.left, depth + 1) + numericValue(value.right, depth + 1)
        elseif value.type == "multiply" then
            result = numericValue(value.left, depth + 1) * numericValue(value.right, depth + 1)
        else
            error("Unknown numeric expression: " .. tostring(value.type))
        end
    end
    assert(type(result) == "number" and math.abs(result) < math.huge,
        "Numeric value must be finite")
    return result
end

local function questData(definition)
    local payload = data(definition)
    assert(type(payload.questId) == "number" and payload.questId >= 0
        and payload.questId < math.huge and payload.questId % 1 == 0,
        "Quest id must be a non-negative integer")
    local progress = numericValue(payload.progress)
    assert(progress % 1 == 0, "Quest progress must be an integer")
    return payload, progress
end

local function itemAt(definition)
    local coordinate = assert(data(definition).position, "Behavior requires a position")
    return world:getItemOnField(position(coordinate.x, coordinate.y, coordinate.z))
end

local function matchingItemAt(definition)
    local payload = data(definition)
    local coordinate = assert(payload.position, "Behavior requires a position")
    assert(type(payload.item) == "string", "Behavior requires an item reference")
    local entry = assert(Registries.findByName("illarion:items", payload.item), "Unknown item")
    local itemId = entry:getMetadata("id")
    local pos = position(coordinate.x, coordinate.y, coordinate.z)
    local dimension = Dimensions.getDefault()
    for _, entity in ipairs(dimension:getEntitiesAt(pos)) do
        if entity:hasTag("illarion:item") then
            local item = Item.fromSeleneEntity(entity)
            if item.id == itemId then return item end
        end
    end
    local tiles = dimension:getTilesAt(pos)
    for i = #tiles, 1, -1 do
        if tiles[i]:hasTag("illarion:item") then
            local item = Item.fromSeleneTile(tiles[i])
            if item.id == itemId then return item end
        end
    end
    return nil
end

local function baseTileAt(coordinate)
    local tiles = Dimensions.getDefault():getTilesAt(position(coordinate.x, coordinate.y, coordinate.z))
    return tiles[1]
end

function m.registerBehaviorDefaults(behaviors)
    local function registerCalendarCondition(kind, field, unit, minimum, maximum)
        behaviors:registerCondition(kind, function(condition)
            local values = data(condition)[field]
            assert(type(values) == "table" and #values > 0,
                field .. " must be a non-empty array")
            local count = 0
            for key in pairs(values) do
                assert(type(key) == "number" and key >= 1 and key % 1 == 0,
                    field .. " must be an array")
                count = count + 1
            end
            local current = world:getTime(unit)
            local matches = false
            for i = 1, count do
                local value = values[i]
                assert(type(value) == "number" and value % 1 == 0
                    and value >= minimum and value <= maximum,
                    field .. " must contain integers from " .. minimum .. " to " .. maximum)
                if value == current then matches = true end
            end
            return matches
        end, { type = "object", properties = {
            [field] = { type = "array", valueType = { type = "integer", min = minimum, max = maximum } }
        } })
    end

    registerCalendarCondition("is_hour", "hours", "hour", 0, 23)
    registerCalendarCondition("is_month", "months", "month", 1, 16)

    behaviors:registerAction("unlock_door", function(action)
        local item = itemAt(action)
        if item then return require("base.keys").UnlockDoor(item) end
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerAction("open_door", function(action)
        local item = itemAt(action)
        if item then return require("base.doors").OpenDoor(item) end
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerAction("close_door", function(action)
        local item = itemAt(action)
        if item then return require("base.doors").CloseDoor(item) end
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerAction("lock_door", function(action)
        local item = itemAt(action)
        if item then return require("base.keys").LockDoor(item) end
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerAction("swap_tile", function(action)
        local payload = data(action)
        local coordinate = assert(payload.position, "Swap tile requires a position")
        assert(type(payload.oldTile) == "string", "Swap tile requires an old tile reference")
        assert(type(payload.tile) == "string", "Swap tile requires a tile reference")
        local oldEntry = assert(Registries.findByName("tiles", payload.oldTile), "Unknown old tile")
        local entry = assert(Registries.findByName("tiles", payload.tile), "Unknown tile")
        local tile = baseTileAt(coordinate)
        if not tile or tile:getMetadata("tileId") ~= oldEntry:getMetadata("tileId") then return false end
        return world:changeTile(entry:getMetadata("tileId"), position(coordinate.x, coordinate.y, coordinate.z))
    end, { type = "object", properties = {
        position = "coordinate",
        oldTile = { type = "registry", registry = "tiles" },
        tile = { type = "registry", registry = "tiles" }
    } })

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

    behaviors:registerAction("swap_item_in_slot", function(action, context)
        local payload = data(action)
        local slot = payload.slot
        assert(type(slot) == "number" and slot >= 0 and slot <= 11 and slot % 1 == 0,
            "Equipment slot must be an integer from 0 to 11")
        assert(type(payload.oldItem) == "string", "Swap item requires an old item reference")
        local oldEntry = assert(Registries.findByName("illarion:items", payload.oldItem), "Unknown old item")
        assert(type(payload.item) == "string", "Swap item requires an item reference")
        local entry = assert(Registries.findByName("illarion:items", payload.item), "Unknown item")
        assert(payload.data == nil or (type(payload.data) == "number"
            and payload.data == payload.data and math.abs(payload.data) < math.huge),
            "Item data must be a finite number")
        local equipment = InventoryManager.GetEquipment(character(context))
        local item = equipment:getItem(slot)
        if item == nil or InventoryManager.IsBlockedHandItem(item)
            or item.def:getMetadata("id") ~= oldEntry:getMetadata("id") then return false end
        item.def = entry
        if payload.data ~= nil then
            item.data = item.data or {}
            item.data.data = payload.data ~= 0 and payload.data or nil
        end
        equipment:slotUpdated(slot)
        return true
    end, { type = "object", properties = {
        slot = { type = "integer", min = 0, max = 11 },
        oldItem = { type = "registry", registry = "illarion:items" },
        item = { type = "registry", registry = "illarion:items" },
        data = { type = "number", optional = true }
    } })

    local transformPayloadSchema = { type = "object", properties = {
        oldItem = { type = "registry", registry = "illarion:items" },
        item = { type = "registry", registry = "illarion:items" },
        count = { type = "integer", min = 1, optional = true },
        quality = { type = "integer", min = 0, optional = true },
        data = { type = "number", optional = true }
    } }
    behaviors:registerAction("transform_item", function(action, context)
        local payload = data(action)
        if payload.onSuccess then behaviors:validate({ actions = payload.onSuccess }) end
        assert(type(payload.item) == "string", "Transform item requires an item reference")
        local entry = assert(Registries.findByName("illarion:items", payload.item), "Unknown item")
        assert(type(payload.oldItem) == "string", "Transform item requires a source item reference")
        local oldEntry = assert(Registries.findByName("illarion:items", payload.oldItem), "Unknown source item")
        local oldId = oldEntry:getMetadata("id")
        local item = context and context.item
        if not item or item.id ~= oldId then
            local visited = {}
            local function find(inventory)
                if not inventory or visited[inventory] then return end
                visited[inventory] = true
                for _, slot in ipairs(inventory:getSlots()) do
                    local candidate = inventory:getItem(slot)
                    if candidate and candidate.def:getMetadata("id") == oldId then
                        return Item.fromSeleneInventoryItem(inventory:getInventoryItem(slot))
                    end
                    local nested = candidate and find(candidate.content)
                    if nested then return nested end
                end
            end
            local user = character(context)
            item = find(InventoryManager.GetBelt(user))
                or find(InventoryManager.GetEquipment(user))
                or find(InventoryManager.GetBackpack(user))
        end
        if not item then return false end
        assert(payload.quality == nil or (type(payload.quality) == "number" and payload.quality >= 0
            and payload.quality < math.huge and payload.quality % 1 == 0),
            "Item quality must be a non-negative integer")
        assert(payload.data == nil or (type(payload.data) == "number" and math.abs(payload.data) < math.huge),
            "Item data must be a finite number")
        local count = payload.count
        assert(count == nil or (type(count) == "number" and count >= 1
            and count < math.huge and count % 1 == 0), "Transform count must be a positive integer")
        if count ~= nil then
            if item.number < count then return false end
            local remaining = character(context):createItem(entry:getMetadata("id"), count,
                payload.quality or item.quality, payload.data or 0)
            -- createItem may fill only part of a requested stack.
            local created = count - remaining
            if created > 0 then world:erase(item, created) end
            if remaining ~= 0 then return false end
        else
            item.id = entry:getMetadata("id")
            if payload.quality ~= nil then item.quality = payload.quality end
            if payload.data ~= nil then item.data = payload.data end
            world:changeItem(item)
        end
        if payload.onSuccess then behaviors:run({ actions = payload.onSuccess }, context) end
        return true
    end, transformPayloadSchema)

    behaviors:registerAction("increase_quest_progress", function(action, context)
        local payload, progress = questData(action)
        local user = character(context)
        return user:setQuestProgress(payload.questId, user:getQuestProgress(payload.questId) + progress)
    end, { type = "object", properties = {
        questId = { type = "integer", min = 0 },
        progress = "any"
    } })

    behaviors:registerCondition("is_magic_type", function(condition, context)
        local magicType = data(condition).magicType
        assert(type(magicType) == "number" and magicType >= 0 and magicType < math.huge
            and magicType % 1 == 0, "Magic type must be a non-negative integer")
        return character(context):getMagicType() == magicType
    end, { type = "object", properties = {
        magicType = { type = "integer", min = 0 }
    } })

    behaviors:registerAction("create_item_at", function(action)
        local payload = data(action)
        local coordinate = assert(payload.position, "Create item requires a position")
        assert(type(payload.item) == "string", "Create item requires an item reference")
        local entry = assert(Registries.findByName("illarion:items", payload.item), "Unknown item")
        local quality = payload.quality == nil and 333 or payload.quality
        assert(type(quality) == "number" and quality >= 0 and quality < math.huge and quality % 1 == 0,
            "Item quality must be a non-negative integer")
        return world:createItemFromId(entry:getMetadata("id"), 1,
            position(coordinate.x, coordinate.y, coordinate.z), true, quality)
    end, { type = "object", properties = {
        position = "coordinate",
        item = { type = "registry", registry = "illarion:items" },
        quality = { type = "integer", min = 0, optional = true }
    } })

    behaviors:registerAction("give_item", function(action, context)
        local payload = data(action)
        assert(type(payload.item) == "string", "Give item requires an item reference")
        local entry = assert(Registries.findByName("illarion:items", payload.item), "Unknown item")
        local count = payload.count == nil and 1 or payload.count
        local quality = payload.quality == nil and 333 or payload.quality
        local itemData = payload.data == nil and 0 or payload.data
        assert(type(count) == "number" and count >= 1 and count < math.huge and count % 1 == 0,
            "Item count must be a positive integer")
        assert(type(quality) == "number" and quality >= 0 and quality < math.huge and quality % 1 == 0,
            "Item quality must be a non-negative integer")
        assert(type(itemData) == "number" and math.abs(itemData) < math.huge,
            "Item data must be a finite number")
        return character(context):createItem(entry:getMetadata("id"), count, quality, itemData)
    end, { type = "object", properties = {
        item = { type = "registry", registry = "illarion:items" },
        count = { type = "integer", min = 1, optional = true },
        quality = { type = "integer", min = 0, optional = true },
        data = { type = "number", optional = true }
    } })

    behaviors:registerAction("increase_skill", function(action, context)
        local payload = data(action)
        assert(type(payload.skill) == "string", "Increase skill requires a skill reference")
        local entry = assert(Registries.findByName("illarion:skills", payload.skill), "Unknown skill")
        assert(type(payload.amount) == "number" and payload.amount >= 0 and payload.amount < math.huge
            and payload.amount % 1 == 0, "Skill amount must be a non-negative integer")
        return character(context):increaseSkill(entry:getMetadata("id"), payload.amount)
    end, { type = "object", properties = {
        skill = { type = "registry", registry = "illarion:skills" },
        amount = { type = "integer", min = 0 }
    } })

    behaviors:registerAction("play_gfx", function(action, context)
        local payload = data(action)
        local gfxId = payload.gfxId
        assert(type(gfxId) == "number" and gfxId >= 0 and gfxId < math.huge and gfxId % 1 == 0,
            "Gfx id must be a non-negative integer")
        local coordinate = payload.position
        local target
        if coordinate ~= nil then
            assert(type(coordinate) == "table", "Gfx position must be a coordinate")
            for _, axis in ipairs({ "x", "y", "z" }) do
                local value = coordinate[axis]
                assert(type(value) == "number" and math.abs(value) < math.huge and value % 1 == 0,
                    "Gfx coordinate components must be finite integers")
            end
            target = position(coordinate.x, coordinate.y, coordinate.z)
        else
            target = character(context).pos
        end
        return world:gfx(gfxId, target)
    end, { type = "object", properties = {
        gfxId = { type = "integer", min = 0 },
        position = { type = "coordinate", optional = true }
    } })

    behaviors:registerAction("play_sound", function(action, context)
        local payload = data(action)
        assert(type(payload.soundId) == "number" and payload.soundId >= 0
            and payload.soundId < math.huge and payload.soundId % 1 == 0,
            "Sound id must be a non-negative integer")
        return world:makeSound(payload.soundId, targetPosition(payload, context))
    end, { type = "object", properties = {
        soundId = { type = "integer", min = 0 },
        position = { type = "coordinate", optional = true }
    } })

    behaviors:registerAction("spawn_monster", function(action, context)
        local payload = data(action)
        local id = monsterId(payload.monster)
        local movePoints = payload.movePoints == nil and 0 or payload.movePoints
        assert(type(movePoints) == "number" and math.abs(movePoints) < math.huge
            and movePoints % 1 == 0, "Monster move points must be a finite integer")
        return world:createMonster(id, targetPosition(payload, context), movePoints)
    end, { type = "object", properties = {
        monster = { type = "registry", registry = "illarion:monsters" },
        position = { type = "coordinate", optional = true },
        movePoints = { type = "integer", optional = true }
    } })

    behaviors:registerAction("set_quest_progress", function(action, context)
        local payload, progress = questData(action)
        return character(context):setQuestProgress(payload.questId, progress)
    end, { type = "object", properties = {
        questId = { type = "integer", min = 0 },
        progress = "any"
    } })

    behaviors:registerAction("warp", function(action, context)
        local coordinate = assert(data(action).position, "Warp requires a position")
        return character(context):warp(position(coordinate.x, coordinate.y, coordinate.z))
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerAction("consume_event", function(_, context)
        assert(context, "Behavior requires an event context").handled = true
    end)

    behaviors:registerAction("consume_item", function(action, context)
        local count = data(action).count or 1
        assert(type(count) == "number" and count >= 1 and count < math.huge and count % 1 == 0,
            "Consume count must be a positive integer")
        local item = assert(context and context.item, "Behavior context requires an item")
        assert(item.number >= count, "Not enough items to consume")
        return world:erase(item, count)
    end, { type = "object", properties = {
        count = { type = "integer", min = 1, optional = true }
    } })

    behaviors:registerAction("increase_attribute", function(action, context)
        local payload = data(action)
        assert(type(payload.attribute) == "string" and payload.attribute ~= "",
            "Attribute requires a name")
        return character(context):increaseAttrib(payload.attribute, numericValue(payload.amount))
    end, { type = "object", properties = { attribute = "string", amount = "any" } })

    behaviors:registerAction("set_attribute", function(action, context)
        local payload = data(action)
        assert(type(payload.attribute) == "string" and payload.attribute ~= "",
            "Attribute requires a name")
        local value = numericValue(payload.value)
        local duration = payload.duration
        assert(duration == nil or (type(duration) == "number" and duration >= 0
            and duration < math.huge), "Attribute duration must be finite non-negative milliseconds")
        local attribute = require("illarion-script-loader.server.lua.lib.attributeManager")
            .GetAttribute(character(context), payload.attribute)
        if duration == nil then return attribute:setValue(value) end
        local key = "behavior:set_attribute"
        local modifier = attribute:addModifier(key, function() return value end)
        return require("selene.schedules").setTimeout(duration, function()
            -- A replacement effect must survive the previous effect's expiry.
            modifier.enabled = false
            attribute:refresh()
        end)
    end, { type = "object", properties = {
        attribute = "string", value = "any",
        duration = { type = "number", min = 0, optional = true }
    } })

    behaviors:registerAction("poison", function(action, context)
        local amount = data(action).amount
        assert(type(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge,
            "Poison amount must be a finite non-negative number")
        return character(context):increasePoisonValue(amount)
    end, { type = "object", properties = { amount = { type = "number", min = 0 } } })

    behaviors:registerAction("talk", function(action, context)
        local payload = data(action)
        assert(type(payload.message) == "string", "Talk message must be a string")
        assert(payload.messageEnglish == nil or type(payload.messageEnglish) == "string",
            "English talk message must be a string")
        local user = character(context)
        user:talkLanguage(Character.say, Player.german, payload.message)
        user:talkLanguage(Character.say, Player.english, payload.messageEnglish or payload.message)
    end, { type = "object", properties = {
        message = "string",
        messageEnglish = { type = "string", optional = true }
    } })

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

    behaviors:registerAction("item_inform", function(action, context)
        local payload = data(action)
        assert(type(payload.message) == "string", "Item inform message must be a string")
        assert(payload.messageEnglish == nil or type(payload.messageEnglish) == "string",
            "English item inform message must be a string")
        local user = character(context)
        local item = assert(context.item, "Item inform requires an item")
        local message = user:getPlayerLanguage() == Player.german and payload.message
            or (payload.messageEnglish or payload.message)
        if context.lookAt then
            context.lookAt.tooltip = { name = message }
        else
            return world:itemInform(user, item, message)
        end
    end, { type = "object", properties = {
        message = "string",
        messageEnglish = { type = "string", optional = true }
    } })

    behaviors:registerAction("inform_nearby", function(action)
        local payload = data(action)
        local coordinate = assert(payload.position, "Inform nearby requires a position")
        assert(type(payload.range) == "number" and payload.range >= 0 and payload.range < math.huge,
            "Inform range must be a finite non-negative number")
        assert(type(payload.message) == "string", "Inform message must be a string")
        assert(payload.messageEnglish == nil or type(payload.messageEnglish) == "string",
            "English inform message must be a string")
        assert(payload.ignoreFloors == nil or type(payload.ignoreFloors) == "boolean",
            "Ignore floors must be a boolean")
        for _, player in pairs(world:getPlayersInRangeOf(position(coordinate.x, coordinate.y, coordinate.z), payload.range)) do
            if payload.ignoreFloors or player.pos.z == coordinate.z then
                player:inform(payload.message, payload.messageEnglish or payload.message)
            end
        end
    end, { type = "object", properties = {
        position = "coordinate",
        range = { type = "number", min = 0 },
        message = "string",
        messageEnglish = { type = "string", optional = true },
        ignoreFloors = { type = "boolean", optional = true }
    } })

    behaviors:registerAction("destroy_item_at", function(action)
        local payload = data(action)
        local amount = payload.amount or 1
        assert(type(amount) == "number" and amount >= 1 and amount < math.huge and amount % 1 == 0,
            "Destroy amount must be a positive integer")
        local item = matchingItemAt(action)
        if not item then return false end
        return world:erase(item, amount)
    end, { type = "object", properties = {
        position = "coordinate",
        amount = { type = "integer", min = 1, optional = true },
        item = { type = "registry", registry = "illarion:items" }
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

    behaviors:registerCondition("attribute_sum_above", function(condition, context)
        local payload = data(condition)
        assert(type(payload.attributes) == "table" and #payload.attributes > 0,
            "Attribute sum requires a non-empty array of attributes")
        assert(type(payload.threshold) == "number" and math.abs(payload.threshold) < math.huge,
            "Attribute threshold must be a finite number")
        local total, count = 0, 0
        local user = character(context)
        for key in pairs(payload.attributes) do
            assert(type(key) == "number" and key >= 1 and key % 1 == 0,
                "Attributes must be an array")
            count = count + 1
        end
        for i = 1, count do
            local attribute = payload.attributes[i]
            assert(type(attribute) == "string" and attribute ~= "", "Attribute name must be a non-empty string")
            total = total + user:increaseAttrib(attribute, 0)
        end
        return total > payload.threshold
    end, { type = "object", properties = {
        attributes = { type = "array", valueType = "string" },
        threshold = "number"
    } })

    behaviors:registerCondition("is_admin", function(_, context)
        return character(context):isAdmin()
    end)

    behaviors:registerCondition("quest_progress", function(condition, context)
        local payload, expected = questData(condition)
        local operator = payload.operator == nil and "equals" or payload.operator
        assert(operator == "equals" or operator == "less_than", "Unknown quest progress operator")
        local progress = character(context):getQuestProgress(payload.questId)
        if operator == "less_than" then return progress < expected end
        return progress == expected
    end, { type = "object", properties = {
        questId = { type = "integer", min = 0 },
        progress = "any",
        operator = { type = "enum", optional = true, values = {
            { value = "equals", label = "equals" },
            { value = "less_than", label = "less than" }
        } }
    } })

    behaviors:registerCondition("is_active_language", function(condition, context)
        local language = data(condition).language
        assert(type(language) == "number" and language >= 0 and language < math.huge and language % 1 == 0,
            "Active language must be a non-negative integer")
        return character(context).activeLanguage == language
    end, { type = "object", properties = {
        language = { type = "integer", min = 0 }
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

    behaviors:registerCondition("is_monster_nearby", function(condition, context)
        local payload = data(condition)
        assert(type(payload.range) == "number" and payload.range >= 0 and payload.range < math.huge,
            "Monster range must be a finite non-negative number")
        local ids
        if payload.monsters ~= nil then
            assert(type(payload.monsters) == "table", "Monsters must be an array of registry references")
            ids = {}
            local count = 0
            for key in pairs(payload.monsters) do
                assert(type(key) == "number" and key >= 1 and key % 1 == 0,
                    "Monsters must be an array of registry references")
                count = count + 1
            end
            for i = 1, count do ids[monsterId(payload.monsters[i])] = true end
        end
        for _, monster in ipairs(world:getMonstersInRangeOf(targetPosition(payload, context), payload.range)) do
            if ids == nil or ids[monster:getMonsterType()] then return true end
        end
        return false
    end, { type = "object", properties = {
        range = { type = "number", min = 0 },
        position = { type = "coordinate", optional = true },
        monsters = { type = "array", optional = true,
            valueType = { type = "registry", registry = "illarion:monsters" } }
    } })

    behaviors:registerCondition("is_character_at", function(condition)
        local coordinate = assert(data(condition).position, "Character condition requires a position")
        return world:isCharacterOnField(position(coordinate.x, coordinate.y, coordinate.z))
    end, { type = "object", properties = { position = "coordinate" } })

    behaviors:registerCondition("is_tile", function(condition)
        local payload = data(condition)
        local coordinate = assert(payload.position, "Tile condition requires a position")
        assert(type(payload.tile) == "string", "Tile condition requires a tile reference")
        local entry = assert(Registries.findByName("tiles", payload.tile), "Unknown tile")
        local tile = baseTileAt(coordinate)
        return tile ~= nil and tile:getMetadata("tileId") == entry:getMetadata("tileId")
    end, { type = "object", properties = {
        position = "coordinate",
        tile = { type = "registry", registry = "tiles" }
    } })

    behaviors:registerCondition("is_item", function(condition, context)
        local payload = data(condition)
        local subject = payload.subject or "item"
        assert(subject == "item" or subject == "targetItem", "Item subject must be item or targetItem")
        assert(type(payload.item) == "string", "Item condition requires an item reference")
        local entry = assert(Registries.findByName("illarion:items", payload.item), "Unknown item")
        assert(payload.data == nil or (type(payload.data) == "number" and math.abs(payload.data) < math.huge),
            "Item data must be a finite number")
        local item = context and context[subject]
        return item ~= nil and item.id == entry:getMetadata("id")
            and (payload.data == nil or item.data == payload.data)
    end, { type = "object", properties = {
        subject = { type = "enum", optional = true, values = {
            { value = "item", label = "item" }, { value = "targetItem", label = "targetItem" }
        } },
        item = { type = "registry", registry = "illarion:items" },
        data = { type = "number", optional = true }
    } })

    behaviors:registerCondition("is_item_at", function(condition)
        return matchingItemAt(condition) ~= nil
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

    local function schedule(action, context)
        local payload = data(action)
        assert(type(payload.delay) == "number" and payload.delay >= 0 and payload.delay < math.huge,
            "Schedule delay must be a finite non-negative number of milliseconds")
        local definition = { actions = payload.actions }
        behaviors:validate(definition)
        return require("selene.schedules").setTimeout(payload.delay, function()
            behaviors:run(definition, context)
        end)
    end
    -- Keep the schema finite while allowing scheduled actions to schedule more work.
    behaviors:registerAction("schedule", schedule)
    behaviors:registerAction("schedule", schedule, { type = "object", properties = {
        delay = { type = "number", min = 0 },
        actions = behaviors:schema().properties.actions
    } })

    local roller = Rolls:new()
    roller:registerType("behavior", function(entry, context)
        return behaviors:run(entry.data, context)
    end)
    local function roll(action, context)
        local definition = data(action)
        roller:validate(definition)
        -- Validate every outcome, including ones that will not be selected.
        for _, pool in ipairs(definition.pools) do
            for _, entry in ipairs(pool.entries) do
                behaviors:validate(entry.data)
            end
        end
        return roller:roll(definition, context)
    end
    -- Register first so nested rolls remain available without recursive schemas.
    behaviors:registerAction("roll", roll)
    roller:registerType("behavior", function(entry, context)
        return behaviors:run(entry.data, context)
    end, behaviors:schema())
    behaviors:registerAction("roll", roll, roller:schema())

    -- Capture the complete action schema without introducing recursive schemas.
    transformPayloadSchema.properties.onSuccess = behaviors:schema().properties.actions
    transformPayloadSchema.properties.onSuccess.optional = true

    return behaviors
end

function m.schema()
    return m.registerBehaviorDefaults(Behaviors:new()):schema().properties
end

return m
