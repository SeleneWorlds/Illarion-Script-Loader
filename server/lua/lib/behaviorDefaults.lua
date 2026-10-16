local Registries = require("selene.registries")
local Dimensions = require("selene.dimensions")
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

local function questData(definition)
    local payload = data(definition)
    assert(type(payload.questId) == "number" and payload.questId >= 0
        and payload.questId < math.huge and payload.questId % 1 == 0,
        "Quest id must be a non-negative integer")
    assert(type(payload.progress) == "number" and math.abs(payload.progress) < math.huge
        and payload.progress % 1 == 0, "Quest progress must be a finite integer")
    return payload
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
        local gfxId = data(action).gfxId
        assert(type(gfxId) == "number" and gfxId >= 0 and gfxId < math.huge and gfxId % 1 == 0,
            "Gfx id must be a non-negative integer")
        return world:gfx(gfxId, character(context).pos)
    end, { type = "object", properties = {
        gfxId = { type = "integer", min = 0 }
    } })

    behaviors:registerAction("set_quest_progress", function(action, context)
        local payload = questData(action)
        return character(context):setQuestProgress(payload.questId, payload.progress)
    end, { type = "object", properties = {
        questId = { type = "integer", min = 0 },
        progress = "integer"
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
        local payload = questData(condition)
        local operator = payload.operator == nil and "equals" or payload.operator
        assert(operator == "equals" or operator == "less_than", "Unknown quest progress operator")
        local progress = character(context):getQuestProgress(payload.questId)
        if operator == "less_than" then return progress < payload.progress end
        return progress == payload.progress
    end, { type = "object", properties = {
        questId = { type = "integer", min = 0 },
        progress = "integer",
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

    return behaviors
end

function m.schema()
    return m.registerBehaviorDefaults(Behaviors:new()):schema().properties
end

return m
