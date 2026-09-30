local SQLite = require("selene.sqlite")
local Config = require("selene.config")
local Json = require("selene.json")
local Registries = require("selene.registries")
local I18n = require("selene.i18n")

local CharacterPersistence = require("illarion-script-loader.server.lua.lib.characterPersistence")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")

local m = {}
local database = SQLite.open("illarion-script-loader/characters.sqlite")
local creationAttributes = {
    "agility", "constitution", "dexterity", "essence",
    "intelligence", "perception", "strength", "willpower"
}

local function getUserId(player)
    local userId = player:getUserId()
    if not userId then
        error("Cannot create a character for a player without a user ID")
    end
    return userId
end

local function plainTable(value)
    if value == nil then
        return {}
    end
    if type(value) ~= "table" then
        value = value:toTable()
    end
    return value
end

local function colourPayload(colour)
    return {
        red = tonumber(colour.red) or 0,
        green = tonumber(colour.green) or 0,
        blue = tonumber(colour.blue) or 0,
        alpha = tonumber(colour.alpha) or 255
    }
end

local function idPayload(entry, key)
    return { id = tonumber(entry[key]) }
end

local function packedColours(colours)
    local result = {}
    for _, colour in pairs(plainTable(colours)) do
        colour = colourPayload(plainTable(colour))
        table.insert(result, string.format("%02x%02x%02x%02x", colour.red, colour.green, colour.blue, colour.alpha))
    end
    return table.concat(result)
end

---Returns the server-authoritative choices and limits used by character creation.
function m.getOptions(compactColours, locale)
    local races = {}
    for _, race in pairs(Registries.findAll("illarion:races")) do
        local raceId = tonumber(race:getMetadata("id"))
        if raceId and raceId >= 0 and raceId <= 5 then
            local attributes = {
                age = { min = race:getField("minAge"), max = race:getField("maxAge") },
                height = { min = race:getField("minHeight"), max = race:getField("maxHeight") },
                weight = { min = race:getField("minWeight"), max = race:getField("maxWeight") },
                total = race:getField("maxAttributePoints")
            }
            for _, name in ipairs(creationAttributes) do
                local title = name:gsub("^%l", string.upper, 1)
                attributes[name] = {
                    min = race:getField("min" .. title),
                    max = race:getField("max" .. title)
                }
            end

            local types = {}
            for typeId, raceType in pairs(plainTable(race:getField("types"))) do
                raceType = plainTable(raceType)
                local resultType = { id = tonumber(typeId), hairs = {}, beards = {}, hairColors = {}, skinColors = {} }
                for _, hair in pairs(plainTable(raceType.hairs)) do
                    table.insert(resultType.hairs, idPayload(plainTable(hair), "hairId"))
                end
                for _, beard in pairs(plainTable(raceType.beards)) do
                    table.insert(resultType.beards, idPayload(plainTable(beard), "beardId"))
                end
                if compactColours then
                    resultType.hairColors = packedColours(raceType.hairColors)
                    resultType.skinColors = packedColours(raceType.skinColors)
                else
                    for _, colour in pairs(plainTable(raceType.hairColors)) do
                        table.insert(resultType.hairColors, colourPayload(plainTable(colour)))
                    end
                    for _, colour in pairs(plainTable(raceType.skinColors)) do
                        table.insert(resultType.skinColors, colourPayload(plainTable(colour)))
                    end
                end
                table.insert(types, resultType)
            end
            table.sort(types, function(a, b) return a.id < b.id end)
            table.insert(races, {
                id = raceId,
                name = race:getMetadata("name") or race:getField("name") or ("race_" .. raceId),
                attributes = attributes,
                types = types
            })
        end
    end
    table.sort(races, function(a, b) return a.id < b.id end)

    local startPacks = {}
    for _, pack in pairs(Registries.findAll("illarion:starter_packs")) do
        local id = tonumber(pack:getMetadata("id"))
        if id then
            local name = locale and I18n.get("characterCreation.startPack." .. id, locale) or nil
            name = name or ("Starter pack " .. id)
            table.insert(startPacks, { id = id, name = name })
        end
    end
    table.sort(startPacks, function(a, b) return a.id < b.id end)
    return { races = races, startPacks = startPacks }
end

local function findById(entries, id)
    for _, entry in ipairs(entries) do
        if entry.id == id then
            return entry
        end
    end
    return nil
end

local function validateColour(value, choices)
    if type(value) ~= "table" then
        return nil
    end
    local colour = {
        red = PayloadValidation.integer(value.red, 0, 255),
        green = PayloadValidation.integer(value.green, 0, 255),
        blue = PayloadValidation.integer(value.blue, 0, 255),
        alpha = PayloadValidation.integer(value.alpha, 0, 255)
    }
    if colour.red == nil or colour.green == nil or colour.blue == nil or colour.alpha == nil then
        return nil
    end
    for _, choice in ipairs(choices) do
        if colour.red == choice.red and colour.green == choice.green
                and colour.blue == choice.blue and colour.alpha == choice.alpha then
            return colour
        end
    end
    return nil
end

---Validates an untrusted character-creation payload against the current registries.
---@return table|nil, string|nil
function m.validate(payload)
    local options = m.getOptions()
    local name = PayloadValidation.string(payload.name, 50)
    if not name or #name < 2 or name:match("^%s") or name:match("%s$") or name:match("%c") then
        return nil, "Use a name of 2-50 characters without leading or trailing spaces."
    end

    local raceId = PayloadValidation.integer(payload.race, 0, 5)
    local race = raceId and findById(options.races, raceId)
    local sex = PayloadValidation.oneOf(payload.sex, { male = true, female = true })
    local typeId = sex == "female" and 1 or 0
    local raceType = race and findById(race.types, typeId)
    local startPack = PayloadValidation.integer(payload.startPack, 0)
    if not race or not raceType or not findById(options.startPacks, startPack) then
        return nil, "Choose a valid race, sex and starter pack."
    end

    local result = { name = name, race = raceId, sex = sex, startPack = startPack }
    for _, field in ipairs({ "age", "height", "weight" }) do
        local limits = race.attributes[field]
        result[field] = PayloadValidation.integer(payload[field], limits.min, limits.max)
        if result[field] == nil then
            return nil, field .. " is outside the range for this race."
        end
    end

    local total = 0
    for _, field in ipairs(creationAttributes) do
        local limits = race.attributes[field]
        result[field] = PayloadValidation.integer(payload[field], limits.min, limits.max)
        if result[field] == nil then
            return nil, field .. " is outside the range for this race."
        end
        total = total + result[field]
    end
    if total ~= race.attributes.total then
        return nil, "Allocate exactly " .. race.attributes.total .. " attribute points."
    end

    result.hair = PayloadValidation.integer(payload.hair, 0)
    result.beard = PayloadValidation.integer(payload.beard, 0)
    if result.hair ~= 0 and not findById(raceType.hairs, result.hair) then
        return nil, "Choose a valid hairstyle."
    end
    if result.beard ~= 0 and not findById(raceType.beards, result.beard) then
        return nil, "Choose a valid beard."
    end
    result.hairColor = validateColour(payload.hairColor, raceType.hairColors)
    result.skinColor = validateColour(payload.skinColor, raceType.skinColors)
    if not result.hairColor or not result.skinColor then
        return nil, "Choose valid hair and skin colours."
    end
    return result
end

local function starterPackData(pack)
    local skills = {}
    for skillName, skill in pairs(plainTable(pack:getField("skills"))) do
        local definition = Registries.findByName("illarion:skills", skillName)
        local id = definition and tonumber(definition:getMetadata("id"))
        if id then
            skills[tostring(id)] = { major = tonumber(plainTable(skill).value) or 0, minor = 0 }
        end
    end
    local belt = {}
    for slot, item in pairs(plainTable(pack:getField("items"))) do
        item = plainTable(item)
        local definition = Registries.findByName("illarion:items", item.itemId)
        local id = definition and tonumber(definition:getMetadata("id"))
        if id then
            table.insert(belt, {
                slot = tonumber(slot),
                item = { id = id, count = tonumber(item.count) or 1, quality = tonumber(item.quality) or 333, data = {} }
            })
        end
    end
    return skills, { equipment = {}, belt = belt, depots = {} }
end

---Creates a character owned by player. Callers must validate the payload first.
---@return integer|nil, string|nil
function m.create(player, data)
    local userId = getUserId(player)
    if #CharacterPersistence.loadCharacterSummaries(player) >= 5 then
        return nil, "You may have at most five characters."
    end
    if #database:query("SELECT id FROM characters WHERE lower(name) = lower(?)", data.name) > 0 then
        return nil, "That name is already in use."
    end
    local pack = Registries.findByMetadata("illarion:starter_packs", "id", data.startPack)
    if not pack then
        return nil, "The selected starter pack does not exist."
    end
    local skills, items = starterPackData(pack)
    local now = os.time()
    database:execute(
        [[
            INSERT INTO characters (
                user_id, name, race, sex, x, y, z, age, weight, body_height,
                strength, dexterity, constitution, agility, intelligence, perception,
                willpower, essence, hair, beard, hair_red, hair_green, hair_blue,
                hair_alpha, skin_red, skin_green, skin_blue, skin_alpha, skills, items,
                created_at, last_saved_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, jsonb(?), jsonb(?), ?, ?)
        ]],
        {
            userId, data.name, data.race, data.sex,
            tonumber(Config.getProperty("spawnX")) or 0,
            tonumber(Config.getProperty("spawnY")) or 0,
            tonumber(Config.getProperty("spawnZ")) or 0,
            data.age, data.weight, data.height,
            data.strength, data.dexterity, data.constitution, data.agility,
            data.intelligence, data.perception, data.willpower, data.essence,
            data.hair, data.beard,
            data.hairColor.red, data.hairColor.green, data.hairColor.blue, data.hairColor.alpha,
            data.skinColor.red, data.skinColor.green, data.skinColor.blue, data.skinColor.alpha,
            Json.encode(skills), Json.encode(items), now, now
        }
    )
    local created = database:query(
        "SELECT id FROM characters WHERE user_id = ? AND name = ? ORDER BY id DESC LIMIT 1",
        { userId, data.name }
    )[1]
    return created and created.id or nil
end

return m
