local SQLite = require("selene.sqlite")
local Players = require("selene.players")

local m = {}
local database = SQLite.open("illarion-script-loader/characters.sqlite")
database:execute([[
    CREATE TABLE IF NOT EXISTS bans (
        scope TEXT NOT NULL CHECK (scope IN ('account', 'character')),
        target_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        expires_at INTEGER,
        PRIMARY KEY (scope, target_id)
    )
]])

local function targetId(scope, id)
    assert(id ~= nil, "Ban target is required.")
    if scope == "character" then
        id = tonumber(id)
        assert(id and id >= 0 and id < math.huge and id % 1 == 0, "Invalid character ID.")
        return string.format("%.0f", id)
    end
    assert(type(id) == "string" and id:find("%S"), "Invalid account ID.")
    return id
end

local function getBan(scope, id)
    if id == nil then return nil end
    return database:query([[
        SELECT reason, expires_at AS expiresAt FROM bans
        WHERE scope = ? AND target_id = ?
          AND (expires_at IS NULL OR expires_at > ?)
    ]], { scope, targetId(scope, id), os.time() })[1]
end

function m.getAccountBan(userId)
    return getBan("account", userId)
end

function m.getCharacterBan(characterId)
    return getBan("character", characterId)
end

function m.message(scope, ban)
    local expiration = ban.expiresAt and (" until " .. os.date("!%Y-%m-%d %H:%M:%S UTC", ban.expiresAt))
        or " indefinitely"
    return "This " .. scope .. " is banned" .. expiration .. ". Reason: " .. ban.reason
end

local function ban(scope, id, reason, expiresAt)
    id = targetId(scope, id)
    assert(type(reason) == "string" and reason:find("%S"), "Ban reason must not be empty.")
    if expiresAt ~= nil then
        assert(type(expiresAt) == "number" and expiresAt < math.huge
            and expiresAt % 1 == 0 and expiresAt > os.time(), "Expiration must be a future Unix timestamp.")
    end
    -- Keep NULL out of Lua parameter arrays, where nil would create a hole.
    local expirationSql = expiresAt ~= nil and "?" or "NULL"
    local parameters = { scope, id, reason }
    if expiresAt ~= nil then table.insert(parameters, expiresAt) end
    database:execute(
        "INSERT INTO bans (scope, target_id, reason, expires_at) VALUES (?, ?, ?, " .. expirationSql .. ") "
            .. "ON CONFLICT(scope, target_id) DO UPDATE SET reason = excluded.reason, expires_at = excluded.expires_at",
        parameters
    )

    local message = m.message(scope, { reason = reason, expiresAt = expiresAt })
    for _, player in ipairs(Players.getOnlinePlayers()) do
        local matches = scope == "account" and player:getUserId() == id
        if scope == "character" and player:getControlledEntity() then
            matches = targetId(scope, Character.fromSelenePlayer(player).id) == id
        end
        if matches then player:kick(message) end
    end
end

---expiresAt is a Unix timestamp in seconds; nil means indefinite.
function m.banAccount(userId, reason, expiresAt)
    ban("account", userId, reason, expiresAt)
end

---expiresAt is a Unix timestamp in seconds; nil means indefinite.
function m.banCharacter(characterId, reason, expiresAt)
    ban("character", characterId, reason, expiresAt)
end

function m.unbanAccount(userId)
    return database:execute("DELETE FROM bans WHERE scope = ? AND target_id = ?",
        { "account", targetId("account", userId) }) > 0
end

function m.unbanCharacter(characterId)
    return database:execute("DELETE FROM bans WHERE scope = ? AND target_id = ?",
        { "character", targetId("character", characterId) }) > 0
end

return m
