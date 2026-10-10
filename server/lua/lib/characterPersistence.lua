local SQLite = require("selene.sqlite")
local Json = require("selene.json")
local Registries = require("selene.registries")
local Logging = require("selene.logging")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local SkillManager = require("illarion-script-loader.server.lua.lib.skillManager")

local m = {}

---@class CharacterSummary
---@field id integer
---@field name string
---@field race integer
---@field sex string
---@field createdAt integer

---@class PersistedCharacterSummary: CharacterSummary
---@field x integer
---@field y integer
---@field z integer

---@class FullCharacter: CharacterSummary
---@field x integer
---@field y integer
---@field z integer
---@field facing integer
---@field age integer
---@field weight integer
---@field bodyHeight integer
---@field hitpoints integer
---@field mana integer
---@field foodlevel integer
---@field attitude integer
---@field luck integer
---@field strength integer
---@field dexterity integer
---@field constitution integer
---@field agility integer
---@field intelligence integer
---@field perception integer
---@field willpower integer
---@field essence integer
---@field alive boolean|integer
---@field magicType integer
---@field magicFlagsMage integer
---@field magicFlagsPriest integer
---@field magicFlagsBard integer
---@field magicFlagsDruid integer
---@field poison integer
---@field mentalCapacity integer
---@field hair integer
---@field beard integer
---@field hairRed integer
---@field hairGreen integer
---@field hairBlue integer
---@field hairAlpha integer
---@field skinRed integer
---@field skinGreen integer
---@field skinBlue integer
---@field skinAlpha integer
---@field totalOnlineTime integer
---@field lastSavedAt integer
---@field skills table
---@field items table
---@field introductions table
---@field quests table
---@field longTimeEffects table

local database = SQLite.open("illarion-script-loader/characters.sqlite")
database:execute([[
    CREATE TABLE IF NOT EXISTS characters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        race INTEGER NOT NULL,
        sex TEXT NOT NULL,
        x INTEGER NOT NULL,
        y INTEGER NOT NULL,
        z INTEGER NOT NULL,
        facing INTEGER NOT NULL DEFAULT 4,
        age INTEGER NOT NULL DEFAULT 18,
        weight INTEGER NOT NULL DEFAULT 0,
        body_height INTEGER NOT NULL DEFAULT 0,
        hitpoints INTEGER NOT NULL DEFAULT 10000,
        mana INTEGER NOT NULL DEFAULT 0,
        foodlevel INTEGER NOT NULL DEFAULT 30000,
        attitude INTEGER NOT NULL DEFAULT 0,
        luck INTEGER NOT NULL DEFAULT 0,
        strength INTEGER NOT NULL DEFAULT 0,
        dexterity INTEGER NOT NULL DEFAULT 0,
        constitution INTEGER NOT NULL DEFAULT 0,
        agility INTEGER NOT NULL DEFAULT 0,
        intelligence INTEGER NOT NULL DEFAULT 0,
        perception INTEGER NOT NULL DEFAULT 0,
        willpower INTEGER NOT NULL DEFAULT 0,
        essence INTEGER NOT NULL DEFAULT 0,
        alive INTEGER NOT NULL DEFAULT 1,
        magic_type INTEGER NOT NULL DEFAULT 0,
        magic_flags_mage INTEGER NOT NULL DEFAULT 0,
        magic_flags_priest INTEGER NOT NULL DEFAULT 0,
        magic_flags_bard INTEGER NOT NULL DEFAULT 0,
        magic_flags_druid INTEGER NOT NULL DEFAULT 0,
        poison INTEGER NOT NULL DEFAULT 0,
        mental_capacity INTEGER NOT NULL DEFAULT 10000,
        hair INTEGER NOT NULL DEFAULT 0,
        beard INTEGER NOT NULL DEFAULT 0,
        hair_red INTEGER NOT NULL DEFAULT 255,
        hair_green INTEGER NOT NULL DEFAULT 255,
        hair_blue INTEGER NOT NULL DEFAULT 255,
        hair_alpha INTEGER NOT NULL DEFAULT 255,
        skin_red INTEGER NOT NULL DEFAULT 255,
        skin_green INTEGER NOT NULL DEFAULT 255,
        skin_blue INTEGER NOT NULL DEFAULT 255,
        skin_alpha INTEGER NOT NULL DEFAULT 255,
        total_online_time INTEGER NOT NULL DEFAULT 0,
        skills JSONB NOT NULL DEFAULT '{}',
        items JSONB NOT NULL DEFAULT '{}',
        introductions JSONB NOT NULL DEFAULT '{}',
        quests JSONB NOT NULL DEFAULT '{}',
        long_time_effects JSONB NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL,
        last_saved_at INTEGER NOT NULL
    )
]])

local function getUserId(player)
    local userId = player:getUserId()
    if not userId then
        error("Cannot load characters for a player without a user ID")
    end
    return userId
end

---Loads the small record used by character selection.
---@return CharacterSummary[]
function m.loadCharacterSummaries(player)
    local userId = getUserId(player)
    local characters = database:query(
        [[
            SELECT id, name, race, sex, created_at AS "createdAt"
            FROM characters
            WHERE user_id = ?
            ORDER BY id
        ]],
        userId
    )

    return characters
end

---Loads the small records for all persisted characters.
---@return PersistedCharacterSummary[]
function m.loadAllCharacterSummaries()
    return database:query([[
        SELECT id, name, race, sex, x, y, z, created_at AS "createdAt"
        FROM characters
        ORDER BY id
    ]])
end

---Returns the account ID that owns a persisted character.
---@return string
function m.getUserIdForCharacter(characterId)
    local userId = database:scalar("SELECT user_id FROM characters WHERE id = ?", characterId)
    return assert(userId, "Character no longer exists.")
end

---Updates the position of a character that is not currently loaded.
function m.updateOfflineCharacterPosition(characterId, x, y, z)
    database:execute(
        "UPDATE characters SET x = ?, y = ?, z = ?, last_saved_at = ? WHERE id = ?",
        { x, y, z, os.time(), characterId }
    )
end

---Updates the race of a character that is not currently loaded.
function m.updateOfflineCharacterRace(characterId, raceId)
    database:execute(
        "UPDATE characters SET race = ?, last_saved_at = ? WHERE id = ?",
        { raceId, os.time(), characterId }
    )
end

---Updates the sex of a character that is not currently loaded.
function m.updateOfflineCharacterSex(characterId, sex)
    assert(sex == "male" or sex == "female", "Sex must be male or female.")
    database:execute(
        "UPDATE characters SET sex = ?, last_saved_at = ? WHERE id = ?",
        { sex, os.time(), characterId }
    )
end

---Updates a character's name, provided it is not already used by another character.
function m.updateCharacterName(characterId, name)
    local duplicate = database:query(
        "SELECT id FROM characters WHERE lower(name) = lower(?) AND id <> ?",
        name,
        characterId
    )
    assert(#duplicate == 0, "That name is already in use.")
    database:execute(
        "UPDATE characters SET name = ?, last_saved_at = ? WHERE id = ?",
        { name, os.time(), characterId }
    )
end

---Updates the magic type of a character that is not currently loaded.
---@return integer oldMagicType
function m.updateOfflineCharacterMagicType(characterId, magicType)
    local rows = database:query("SELECT magic_type AS magicType FROM characters WHERE id = ?", characterId)
    local character = assert(rows[1], "Character no longer exists.")
    database:execute(
        "UPDATE characters SET magic_type = ?, last_saved_at = ? WHERE id = ?",
        { magicType, os.time(), characterId }
    )
    return character.magicType
end

---Updates a skill of a character that is not currently loaded.
---@return number oldValue
---@return number newValue
function m.updateOfflineCharacterSkill(characterId, skillId, value, setExact)
    local rows = database:query("SELECT json(skills) AS skills FROM characters WHERE id = ?", characterId)
    local character = assert(rows[1], "Character no longer exists.")
    local skills = Json.decode(character.skills) or {}
    local key = tostring(skillId)
    local savedSkill = skills[key] or { major = 0, minor = 0 }
    local oldValue = tonumber(savedSkill.major) or 0
    local newValue = setExact and value or oldValue + value
    newValue = math.max(0, math.min(100, newValue))
    savedSkill.major = newValue
    savedSkill.minor = tonumber(savedSkill.minor) or 0
    skills[key] = savedSkill
    database:execute(
        "UPDATE characters SET skills = jsonb(?), last_saved_at = ? WHERE id = ?",
        { Json.encode(skills), os.time(), characterId }
    )
    return oldValue, newValue
end

local persistedAttributeColumns = {
    agility = { column = "agility", max = 255 },
    constitution = { column = "constitution", max = 255 },
    dexterity = { column = "dexterity", max = 255 },
    essence = { column = "essence", max = 255 },
    intelligence = { column = "intelligence", max = 255 },
    perception = { column = "perception", max = 255 },
    strength = { column = "strength", max = 255 },
    willpower = { column = "willpower", max = 255 },
    hitpoints = { column = "hitpoints", max = 10000 },
    mana = { column = "mana", max = 10000 },
    foodlevel = { column = "foodlevel", max = 60000 },
    age = { column = "age" },
    body_height = { column = "body_height" },
    poisonvalue = { column = "poison" },
    attitude = { column = "attitude" },
    luck = { column = "luck" },
    weight = { column = "weight" },
    mentalcapacity = { column = "mental_capacity" },
}

---Updates a persisted attribute of a character that is not currently loaded.
---@return number oldValue
---@return number newValue
function m.updateOfflineCharacterAttribute(characterId, attribute, value)
    local definition = assert(persistedAttributeColumns[attribute], "Attribute is not persisted for offline characters.")
    local column = definition.column
    if definition.max then
        value = math.max(0, math.min(definition.max, value))
    end
    local rows = database:query("SELECT " .. column .. " AS value FROM characters WHERE id = ?", characterId)
    local character = assert(rows[1], "Character no longer exists.")
    local aliveUpdate = attribute == "hitpoints" and ", alive = ?" or ""
    local values = { value, os.time() }
    if attribute == "hitpoints" then
        values[#values + 1] = value > 0 and 1 or 0
    end
    values[#values + 1] = characterId
    database:execute(
        "UPDATE characters SET " .. column .. " = ?, last_saved_at = ?" .. aliveUpdate .. " WHERE id = ?",
        values
    )
    return character.value, value
end


---Loads the complete scalar record for one character owned by the player.
---@return FullCharacter|nil
function m.loadCharacter(player, characterId)
    local characters = database:query(
        [[
            SELECT id, name, race, sex, x, y, z, facing, age, weight,
                   body_height AS "bodyHeight", hitpoints, mana, foodlevel,
                   attitude, luck, strength, dexterity, constitution, agility,
                   intelligence, perception, willpower, essence, alive,
                   magic_type AS "magicType",
                   magic_flags_mage AS "magicFlagsMage",
                   magic_flags_priest AS "magicFlagsPriest",
                   magic_flags_bard AS "magicFlagsBard",
                   magic_flags_druid AS "magicFlagsDruid",
                   poison, mental_capacity AS "mentalCapacity", hair, beard,
                   hair_red AS "hairRed", hair_green AS "hairGreen",
                   hair_blue AS "hairBlue", hair_alpha AS "hairAlpha",
                   skin_red AS "skinRed", skin_green AS "skinGreen",
                   skin_blue AS "skinBlue", skin_alpha AS "skinAlpha",
                   total_online_time AS "totalOnlineTime",
                   json(skills) AS skills, json(items) AS items,
                   json(introductions) AS introductions,
                   json(quests) AS quests,
                   json(long_time_effects) AS "longTimeEffects",
                   created_at AS "createdAt", last_saved_at AS "lastSavedAt"
            FROM characters
            WHERE user_id = ? AND id = ?
        ]],
        { getUserId(player), characterId }
    )
    local character = characters[1]
    if character then
        for _, field in ipairs({
            "skills", "items", "introductions", "quests", "longTimeEffects"
        }) do
            character[field] = Json.decode(character[field])
        end
    end
    return character
end

local function attributeValue(character, name)
    return AttributeManager.GetAttribute(character, name):getEffectiveValue()
end

local function copyStringMap(source)
    local result = {}
    if source == nil then
        return result
    end

    -- Runtime-data maps are ObservableMaps, which Lua exposes as userdata.
    -- Convert those to a plain table before using the standard iterator.
    if type(source) ~= "table" then
        source = source:toTable()
    end

    for key, value in pairs(source) do
        result[tostring(key)] = value
    end
    return result
end

local function serializeItem(item)
    local result = {
        id = tonumber(item.def:getMetadata("id")),
        count = tonumber(item.count) or 1,
        wear = tonumber(item.wear) or 0,
        quality = tonumber(item.quality) or 333,
        data = copyStringMap(item.data)
    }
    if item.content then
        local container = InventoryManager.GetContentsContainer({ SeleneItem = item })
        if container then
            result.content = {}
            for _, slotId in ipairs(container:getSlots()) do
                local child = container:getItem(slotId)
                if child then
                    table.insert(result.content, { slot = slotId, item = serializeItem(child) })
                end
            end
        end
    end
    return result
end

local function serializeInventory(inventory)
    local result = {}
    for _, slotId in ipairs(inventory:getSlots()) do
        local item = inventory:getItem(slotId)
        if item then
            table.insert(result, { slot = slotId, item = serializeItem(item) })
        end
    end
    return result
end

local function serializeItems(character)
    local result = {
        equipment = serializeInventory(InventoryManager.GetEquipment(character)),
        belt = serializeInventory(InventoryManager.GetBelt(character)),
        depots = {}
    }
    local inventories = character.SeleneEntity:getRuntimeData(DataKeys.Inventories)
    for name, inventory in pairs(inventories) do
        local depotId = type(name) == "string" and name:match("^depot:(%d+)$") or nil
        if depotId then
            table.insert(result.depots, {
                id = tonumber(depotId),
                items = serializeInventory(inventory)
            })
        end
    end
    return result
end

local function serializeSkills(character)
    local result = {}
    for _, skill in pairs(Registries.findAll("illarion:skills")) do
        local skillId = tonumber(skill:getMetadata("id"))
        if skillId then
            local major = SkillManager.GetMajorSkillAttribute(character, skillId):getEffectiveValue()
            local minor = SkillManager.GetMinorSkillAttribute(character, skillId):getEffectiveValue()
            if major ~= 0 or minor ~= 0 then
                result[tostring(skillId)] = { major = major, minor = minor }
            end
        end
    end
    return result
end

local function serializeQuests(entity)
    local result = {}
    local quests = entity:getRuntimeData(DataKeys.Quests)
    for questId, quest in pairs(quests) do
        result[tostring(questId)] = {
            progress = quest.progress,
            time = quest.time
        }
    end
    return result
end

local function serializeEffects(entity)
    local result = {}
    for effectName, effectData in pairs(entity:getRuntimeData(DataKeys.Effects)) do
        result[tostring(effectName)] = {
            nextCalled = effectData.nextCalled or 0,
            numberCalled = effectData.numberCalled or 0,
            values = copyStringMap(effectData.values)
        }
    end
    return result
end

local function deserializeItem(saved)
    local itemDef = Registries.findByMetadata("illarion:items", "id", tonumber(saved.id))
    if not itemDef then
        error("Cannot restore unknown item id " .. tostring(saved.id))
    end
    return {
        def = itemDef,
        count = tonumber(saved.count) or 1,
        wear = tonumber(saved.wear) or 0,
        quality = tonumber(saved.quality) or 333,
        data = copyStringMap(saved.data)
    }
end

local function restoreSafely(description, restore)
    local ok, restoreError = pcall(restore)
    if not ok then
        Logging.error("Failed to restore character " .. description .. ": " .. tostring(restoreError))
    end
end

local function restoreInventory(inventory, savedItems, inventoryName, strict)
    local restoredSlots = {}
    for _, entry in ipairs(savedItems or {}) do
        local function restore()
            local slotId = tonumber(entry.slot)
            if not slotId or not inventory:hasSlot(slotId) then
                error("Cannot restore item into invalid slot " .. tostring(entry.slot))
            end
            if strict and restoredSlots[slotId] then
                error("Duplicate saved item slot " .. tostring(entry.slot))
            end
            restoredSlots[slotId] = true
            local item = deserializeItem(entry.item)
            if entry.item.content then
                local contents = InventoryManager.GetContentsContainer({ SeleneItem = item })
                if not contents then
                    error("Persisted contents belong to non-container item " .. tostring(entry.item.id))
                end
                restoreInventory(contents, entry.item.content, inventoryName .. " container in slot " .. tostring(slotId), strict)
            end
            inventory:setItem(slotId, item)
        end
        if strict then restore()
        else restoreSafely("item in " .. inventoryName .. " slot " .. tostring(entry.slot), restore) end
    end
end

function m.moveDepotContentFrom(target, sourceId, targetDepotId, sourceDepotId)
    local source
    for _,player in ipairs(world:getPlayersOnline()) do
        if player.id == sourceId then source = player; break end
    end
    if sourceId == target.id then source = target end
    local replacement, sourceItems, targetItems
    local begun = false
    local ok, result = pcall(function()
        database:execute("BEGIN IMMEDIATE")
        begun = true
        local sourceRow = database:query("SELECT json(items) AS items FROM characters WHERE id = ?", {sourceId})[1]
        local targetRow = sourceId == target.id and sourceRow
            or database:query("SELECT id FROM characters WHERE id = ?", {target.id})[1]
        if not sourceRow or not targetRow then database:execute("ROLLBACK"); begun = false; return false end
        sourceItems = source and serializeItems(source) or Json.decode(sourceRow.items)
        sourceItems.depots = sourceItems.depots or {}
        local sourceIndex, depot
        for index,entry in ipairs(sourceItems.depots) do
            if tonumber(entry.id) == sourceDepotId then sourceIndex, depot = index, entry; break end
        end
        if not depot then database:execute("ROLLBACK"); begun = false; return false end
        if sourceId == target.id and sourceDepotId == targetDepotId then
            database:execute("ROLLBACK"); begun = false; return true
        end
        replacement = InventoryManager.CreateDetachedDepot(target, targetDepotId)
        restoreInventory(replacement, depot.items, "transferred depot", true)
        table.remove(sourceItems.depots, sourceIndex)
        targetItems = sourceId == target.id and sourceItems or serializeItems(target)
        for index=#targetItems.depots,1,-1 do
            if tonumber(targetItems.depots[index].id) == targetDepotId then table.remove(targetItems.depots, index) end
        end
        targetItems.depots[#targetItems.depots+1] = {id=targetDepotId, items=depot.items or {}}
        if sourceId ~= target.id then
            database:execute("UPDATE characters SET items = ? WHERE id = ?", {Json.encode(sourceItems), sourceId})
        end
        database:execute("UPDATE characters SET items = ? WHERE id = ?", {Json.encode(targetItems), target.id})
        database:execute("COMMIT")
        begun = false
        return true
    end)
    if not ok then
        if begun then pcall(database.execute, database, "ROLLBACK") end
        Logging.error("Failed to transfer depot: " .. tostring(result))
        return false
    end
    if not result or not replacement then return result end
    if source then
        source.SeleneEntity:getRuntimeData(DataKeys.Inventories)["depot:" .. sourceDepotId] = nil
    end
    target.SeleneEntity:getRuntimeData(DataKeys.Inventories)["depot:" .. targetDepotId] = replacement
    InventoryManager.CloseAllShowcases(target)
    if source and source ~= target then InventoryManager.CloseAllShowcases(source) end
    return true
end

function m.restoreCollections(character, saved)
    local entity = character.SeleneEntity

    for skillId, value in pairs(saved.skills or {}) do
        restoreSafely("skill " .. tostring(skillId), function()
            character:setSkill(tonumber(skillId), tonumber(value.major) or 0, tonumber(value.minor) or 0)
        end)
    end

    local introductions = entity:getRuntimeData(DataKeys.Introductions)
    for characterId, relationship in pairs(saved.introductions or {}) do
        restoreSafely("introduction " .. tostring(characterId), function()
            introductions[tonumber(characterId) or characterId] = {
                introduced = relationship.introduced == true,
                customName = relationship.customName
            }
        end)
    end

    local quests = entity:getRuntimeData(DataKeys.Quests)
    for questId, value in pairs(saved.quests or {}) do
        restoreSafely("quest " .. tostring(questId), function()
            local id = tonumber(questId) or questId
            quests[id] = {
                progress = tonumber(value.progress) or 0,
                time = tonumber(value.time) or 0
            }
        end)
    end

    local effects = entity:getRuntimeData(DataKeys.Effects)
    for effectName, value in pairs(saved.longTimeEffects or {}) do
        restoreSafely("long-time effect " .. tostring(effectName), function()
            if not Registries.findByName("illarion:ltes", effectName) then
                error("Cannot restore unknown long-time effect " .. tostring(effectName))
            end
            effects[effectName] = tablex.observable({
                nextCalled = tonumber(value.nextCalled) or 0,
                numberCalled = tonumber(value.numberCalled) or 0,
                values = tablex.observable(copyStringMap(value.values)),
                addEffectCalled = true
            })
        end)
    end

    local items = saved.items or {}
    restoreSafely("equipment", function()
        local equipment = InventoryManager.GetEquipment(character)
        restoreInventory(equipment, items.equipment, "equipment")
        InventoryManager.UpdateBlockedHand(equipment)
    end)
    restoreSafely("belt", function()
        restoreInventory(InventoryManager.GetBelt(character), items.belt, "belt")
    end)
    for _, depot in ipairs(items.depots or {}) do
        restoreSafely("depot " .. tostring(depot.id), function()
            local numericDepotId = tonumber(depot.id)
            local depotId = numericDepotId and math.tointeger(numericDepotId) or nil
            if not depotId then
                error("Cannot restore invalid depot " .. tostring(depot.id))
            end
            restoreInventory(
                InventoryManager.GetDepot(character, depotId),
                depot.items,
                "depot " .. tostring(depotId)
            )
        end)
    end
end

-- Capture live collections without writing or reloading the character's save.
function m.snapshotCharacter(character)
    local attributes = {}
    for _, name in ipairs({
        "age", "weight", "body_height", "hitpoints", "mana", "foodlevel", "attitude", "luck",
        "strength", "dexterity", "constitution", "agility", "intelligence", "perception", "willpower", "essence"
    }) do
        attributes[name] = attributeValue(character, name)
    end
    return {
        id = character.id,
        attributes = attributes,
        skills = serializeSkills(character),
        items = serializeItems(character),
        quests = serializeQuests(character.SeleneEntity),
        effects = serializeEffects(character.SeleneEntity),
        poison = character:getPoisonValue(),
        mentalCapacity = character:getMentalCapacity(),
    }
end

function m.saveCharacter(player, character)
    if character.SeleneEntity:getRuntimeData(DataKeys.Character)[DataFields.Headless] then
        return
    end
    local userId = getUserId(player)
    local entity = character.SeleneEntity
    local characterData = entity:getRuntimeData(DataKeys.Character)
    local coordinate = entity:getCoordinate()
    local hairColor = character:getHairColour()
    local skinColor = character:getSkinColour()
    local magicFlags = entity:getRuntimeData(DataKeys.MagicFlags)
    local playerData = player:getRuntimeData(DataKeys.Player)
    local now = os.time()
    local sessionStart = playerData[DataFields.CurrentLoginTimestamp] or now
    local totalOnlineTime = (playerData[DataFields.TotalOnlineTime] or 0) + math.max(0, now - sessionStart)

    local skills = Json.encode(serializeSkills(character))
    local items = Json.encode(serializeItems(character))
    local introductions = Json.encode(copyStringMap(entity:getRuntimeData(DataKeys.Introductions)))
    local quests = Json.encode(serializeQuests(entity))
    local longTimeEffects = Json.encode(serializeEffects(entity))

    database:execute("BEGIN IMMEDIATE")
    local ok, saveError = xpcall(database.execute, database,
        [[
            UPDATE characters
            SET name = ?, race = ?, sex = ?, x = ?, y = ?, z = ?, facing = ?,
                age = ?, weight = ?, body_height = ?, hitpoints = ?, mana = ?,
                foodlevel = ?, attitude = ?, luck = ?, strength = ?, dexterity = ?,
                constitution = ?, agility = ?, intelligence = ?, perception = ?,
                willpower = ?, essence = ?, alive = ?, magic_type = ?,
                magic_flags_mage = ?, magic_flags_priest = ?, magic_flags_bard = ?,
                magic_flags_druid = ?, poison = ?, mental_capacity = ?, hair = ?,
                beard = ?, hair_red = ?, hair_green = ?, hair_blue = ?,
                hair_alpha = ?, skin_red = ?, skin_green = ?, skin_blue = ?,
                skin_alpha = ?, total_online_time = ?, skills = jsonb(?), items = jsonb(?),
                introductions = jsonb(?), quests = jsonb(?), long_time_effects = jsonb(?),
                last_saved_at = ?
            WHERE user_id = ? AND id = ?
        ]],
        {
            entity:getName(), characterData[DataFields.Race], characterData[DataFields.Sex],
            coordinate:getX(), coordinate:getY(), coordinate:getZ(), character:getFaceTo(),
            attributeValue(character, "age"), attributeValue(character, "weight"),
            attributeValue(character, "body_height"), attributeValue(character, "hitpoints"),
            attributeValue(character, "mana"), attributeValue(character, "foodlevel"),
            attributeValue(character, "attitude"), attributeValue(character, "luck"),
            character:getBaseAttribute("strength"), character:getBaseAttribute("dexterity"),
            character:getBaseAttribute("constitution"), character:getBaseAttribute("agility"),
            character:getBaseAttribute("intelligence"), character:getBaseAttribute("perception"),
            character:getBaseAttribute("willpower"), character:getBaseAttribute("essence"),
            not characterData[DataFields.Dead], character:getMagicType(),
            magicFlags[Character.mage] or 0, magicFlags[Character.priest] or 0,
            magicFlags[Character.bard] or 0, magicFlags[Character.druid] or 0,
            character:getPoisonValue(), character:getMentalCapacity(), character:getHair(),
            character:getBeard(), hairColor.red, hairColor.green, hairColor.blue, hairColor.alpha,
            skinColor.red, skinColor.green, skinColor.blue, skinColor.alpha,
            totalOnlineTime, skills, items, introductions, quests, longTimeEffects,
            now, userId, characterData[DataFields.ID]
        }
    )
    if not ok then
        character:pageGM(character, "Failed to save")
        database:execute("ROLLBACK")
    else
        database:execute("COMMIT")
    end
end

return m
