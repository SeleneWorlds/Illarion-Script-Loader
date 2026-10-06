local Config = require("selene.config")
local SQLite = require("selene.sqlite")

local m = {}

local database = SQLite.open("illarion-script-loader/characters.sqlite")
local tableAlreadyExisted = database:scalar([[
    SELECT COUNT(*)
    FROM sqlite_master
    WHERE type = 'table' AND name = 'admins'
]]) > 0

database:execute([[
    CREATE TABLE IF NOT EXISTS admins (
        user_id TEXT PRIMARY KEY,
        granted_at INTEGER NOT NULL
    )
]])

local function normalizeUserId(userId)
    userId = tostring(assert(userId, "userId is required")):gsub("^%s+", ""):gsub("%s+$", "")
    assert(userId ~= "", "userId must not be empty")
    return userId
end

-- The configured IDs bootstrap a new database. After that, the table is the
-- source of truth so that revocations survive server restarts.
if not tableAlreadyExisted then
    local initialAdmins = Config.getProperty("initialAdmins") or Config.getProperty("admins") or ""
    for userId in initialAdmins:gmatch("[^,]+") do
        userId = userId:gsub("^%s+", ""):gsub("%s+$", "")
        if userId ~= "" then
            database:execute(
                "INSERT OR IGNORE INTO admins (user_id, granted_at) VALUES (?, ?)",
                { userId, os.time() }
            )
        end
    end
end

function m.isAdmin(userId)
    if userId == nil then
        return false
    end
    return database:scalar("SELECT COUNT(*) FROM admins WHERE user_id = ?", normalizeUserId(userId)) > 0
end

function m.grant(userId)
    return database:execute(
        "INSERT OR IGNORE INTO admins (user_id, granted_at) VALUES (?, ?)",
        { normalizeUserId(userId), os.time() }
    ) > 0
end

function m.revoke(userId)
    return database:execute("DELETE FROM admins WHERE user_id = ?", normalizeUserId(userId)) > 0
end

return m
