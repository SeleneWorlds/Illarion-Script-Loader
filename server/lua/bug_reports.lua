local utf8 = require("utf8")
local Network = require("selene.network")
local HTTP = require("selene.http")
local Config = require("selene.config")
local Json = require("selene.json")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local Persistence = require("illarion-script-loader.server.lua.lib.characterPersistence")
local Validation = require("illarion-script-loader.server.lua.lib.payloadValidation")

local radius = 20
Network.setDefaultPayloadRateLimit("illarion:report_bug", 1 / 60, 2)

-- Copy JSON-compatible runtime values, excluding cycles and engine objects.
local function copyData(value, seen, depth)
    if depth > 12 then return nil end
    local kind = type(value)
    if kind == "string" or kind == "boolean" then
        return value
    elseif kind == "number" then
        if value == value and value ~= math.huge and value ~= -math.huge then return value end
        return nil
    elseif kind == "userdata" then
        local ok, plain = pcall(function() return value:toTable() end)
        if ok then return copyData(plain, seen, depth + 1) end
        return nil
    elseif kind ~= "table" or seen[value] or depth > 12 then
        return nil
    end
    seen[value] = true
    local result = {}
    for key, entry in pairs(value) do
        if type(key) == "string" or type(key) == "number" then
            result[tostring(key)] = copyData(entry, seen, depth + 1)
        end
    end
    seen[value] = nil
    return result
end

local function snapshotEntity(entity)
    local coordinate = entity:getCoordinate()
    local data = {}
    for _, key in ipairs({
        DataKeys.Character, DataKeys.Item, DataKeys.Combat, DataKeys.MagicFlags,
        DataKeys.PersistedAttributes, DataKeys.CurrentAction, DataKeys.LastAction,
    }) do
        if entity:hasRuntimeData(key) then
            data[key] = copyData(entity:getRuntimeData(key), {}, 0)
        end
    end
    return {
        networkId = entity:getNetworkId(),
        definition = entity:getEntityDefinition():getName(),
        name = entity:getName(),
        coordinate = { x = coordinate:getX(), y = coordinate:getY(), z = coordinate:getZ() },
        moving = entity:isMoving(),
        runtimeData = data,
    }
end

Network.handlePayload("illarion:report_bug", function(player, payload)
    local message = Validation.string(payload.message, 16000)
    local entity = player:getControlledEntity()
    local webhookUrl = Config.getProperty("bugReportDiscordWebhook")
    local length = message and utf8.len(message)
    if not length or length > 4000 or not message:find("%S") or not entity
        or not webhookUrl or webhookUrl == "" then
        Network.sendToPlayer(player, "illarion:report_bug_result", { success = false })
        return
    end
    local ok, reportError = pcall(function()
        local character = snapshotEntity(entity)
        character.character = Persistence.snapshotCharacter(Character.fromSelenePlayer(player))
        local surrounding = {}
        for _, nearby in ipairs(entity:getDimension():getEntitiesInRange(entity:getCoordinate(), radius)) do
            if nearby ~= entity then
                surrounding[#surrounding + 1] = snapshotEntity(nearby)
            end
        end
        table.sort(surrounding, function(a, b) return a.networkId < b.networkId end)
        local now = os.time()
        local payload = Json.encode({
            embeds = {{
                title = "Bug report",
                description = message,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ", now),
                fields = {
                    { name = "Character", value = entity:getName(), inline = true },
                    { name = "Account ID", value = tostring(player:getUserId() or "Unknown"), inline = true },
                    { name = "Coordinates", value = string.format("%d, %d, %d",
                        character.coordinate.x, character.coordinate.y, character.coordinate.z) },
                },
            }},
        })
        -- Empty Lua tables encode as objects; Discord requires an empty array here.
        payload = '{"allowed_mentions":{"parse":[]},' .. payload:sub(2)
        local files = {
            { name = "character.json", body = Json.encode({ version = 1, capturedAt = now, character = character }) },
            { name = "entities.json", body = Json.encode({ version = 1, capturedAt = now, radius = radius, entities = surrounding }) },
        }
        -- Choose a boundary absent from every part to avoid delimiter collisions.
        local boundary = "SeleneBugReport"
        while payload:find(boundary, 1, true)
            or files[1].body:find(boundary, 1, true) or files[2].body:find(boundary, 1, true) do
            boundary = boundary .. "X"
        end
        local parts = {
            "--" .. boundary .. '\r\nContent-Disposition: form-data; name="payload_json"\r\n'
                .. "Content-Type: application/json\r\n\r\n" .. payload .. "\r\n",
        }
        for index, file in ipairs(files) do
            parts[#parts + 1] = "--" .. boundary
                .. string.format('\r\nContent-Disposition: form-data; name="files[%d]"; filename="%s"\r\n', index - 1, file.name)
                .. "Content-Type: application/json\r\n\r\n" .. file.body .. "\r\n"
        end
        parts[#parts + 1] = "--" .. boundary .. "--\r\n"
        -- wait=true makes Discord confirm that the message was saved.
        local base, fragment = webhookUrl:match("^([^#]*)(.*)$")
        local replacements
        base, replacements = base:gsub("([?&])wait=[^&]*", "%1wait=true")
        if replacements == 0 then
            base = base .. (base:find("?", 1, true) and "&" or "?") .. "wait=true"
        end
        local result = HTTP.post(base .. fragment, table.concat(parts), {
            ["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
        })
        if not result.success then
            -- Avoid logging HTTP errors containing the webhook token.
            error("Discord webhook returned status " .. tostring(result.status))
        end
    end)
    if not ok then print("[Bug Report] Failed to deliver report:", reportError) end
    Network.sendToPlayer(player, "illarion:report_bug_result", { success = ok })
end)
