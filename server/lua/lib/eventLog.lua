local SQLite = require("selene.sqlite")

local m = {}

local database = SQLite.open("illarion-script-loader/events.sqlite")
database:execute([[
    CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        logged_at INTEGER NOT NULL,
        user_id TEXT,
        character_id INTEGER NOT NULL,
        character_type INTEGER NOT NULL,
        character_name TEXT NOT NULL,
        is_admin INTEGER,
        mode TEXT,
        message TEXT NOT NULL,
        message_english TEXT,
        language INTEGER,
        x INTEGER NOT NULL,
        y INTEGER NOT NULL,
        z INTEGER NOT NULL
    )
]])

local function log(character, eventType, message, isAdmin, mode, messageEnglish, language)
    local coordinate = character.SeleneEntity:getCoordinate()
    local userId = character.SelenePlayer and character.SelenePlayer:getUserId() or nil
    -- Individual parameters preserve optional nil values between required fields.
    database:execute([[
        INSERT INTO events (
            type, logged_at, user_id, character_id, character_type, character_name,
            is_admin, mode, message, message_english, language, x, y, z
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], eventType, os.time(), userId and tostring(userId) or nil, character.id,
        character:getType(), character.name, isAdmin, mode, message, messageEnglish,
        language, coordinate:getX(), coordinate:getY(), coordinate:getZ())
end

function m.logChat(character, mode, message, messageEnglish, language)
    log(character, "chat", message, nil, tostring(mode), messageEnglish, language)
end

function m.logAdmin(character, message, isAdmin)
    log(character, "admin", message, isAdmin and 1 or 0)
end

return m
