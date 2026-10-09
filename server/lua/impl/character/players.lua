local Network = require("selene.network")
local Entities = require("selene.entities")
local HTTP = require("selene.http")
local Json = require("selene.json")
local Config = require("selene.config")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local ChatMode = require("illarion-script-loader.server.lua.lib.chatMode")
local EventLog = require("illarion-script-loader.server.lua.lib.eventLog")
local PlayerManager = require("illarion-script-loader.server.lua.lib.playerManager")

Character.SeleneMethods.inform = function(user, message, messageEnglish, priority)
    if priority ~= nil then
        priority = assert(tonumber(priority), "priority must be a number, was " .. tostring(priority))
    end
    if not user.SelenePlayer then
        return
    end

    local localizedMessage = user:getPlayerLanguage() == Player.english and messageEnglish or message
    local mode
    mode, localizedMessage = ChatMode.parsePrefix(Character.say, localizedMessage)
    Network.sendToPlayer(user.SelenePlayer, "illarion:inform", { Message = localizedMessage, mode = mode })
end

Character.SeleneMethods.pageGM = function(user, message)
    local webhookUrl = Config.getProperty("notifyAdminDiscordWebhook")
    local player = user.SelenePlayer
    local now = os.time()
    local pos = user.pos

    local nearbyPlayers = {}
    for _, nearbyPlayer in ipairs(world:getPlayersInRangeOf(pos, 20)) do
        if nearbyPlayer.id ~= user.id then
            table.insert(nearbyPlayers, string.format("%s (`%s`)", nearbyPlayer.name, nearbyPlayer.id))
        end
    end
    table.sort(nearbyPlayers)

    local nearbyLines = {}
    local nearbyLength = 0
    for index, line in ipairs(nearbyPlayers) do
        local separatorLength = index > 1 and 1 or 0
        if nearbyLength + separatorLength + #line > 990 then
            table.insert(nearbyLines, string.format("... and %d more", #nearbyPlayers - index + 1))
            break
        end
        table.insert(nearbyLines, line)
        nearbyLength = nearbyLength + separatorLength + #line
    end
    local nearbyValue = #nearbyLines > 0 and table.concat(nearbyLines, "\n") or "None"

    local payload = {
        username = Server.getName(),
        embeds = {{
            title = user.name .. " has requested a GM",
            description = message,
            color = 0xE6A23C,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ", now),
            fields = {
                { name = "Character", value = user.name, inline = true },
                { name = "Character ID", value = tostring(user.id), inline = true },
                { name = "Account ID", value = tostring(player:getUserId() or "Unknown"), inline = true },
                { name = "Coordinates", value = string.format("`%d, %d, %d`", pos.x, pos.y, pos.z), inline = true },
                { name = "Language", value = player:getLanguage() or "Unknown", inline = true },
                { name = "Players nearby", value = nearbyValue, inline = false },
            }
        }},
    }
    local result = HTTP.post(webhookUrl, Json.encode(payload))

    if not result.success then
        print("[GM Help] Failed to deliver report for", user.name, "(" .. user.id .. "):", result.status, result.body)
    end
    return result.success
end

Character.SeleneMethods.isAdmin = function(user)
    if not user.SelenePlayer then
        return false
    end
    return PlayerManager.IsAdminUserId(user.SelenePlayer:getUserId())
end

Character.SeleneMethods.getPlayerLanguage = function(user)
    if user.SelenePlayer and user.SelenePlayer:getLanguage() == "de" then
        return Player.german
    end
    return Player.english
end
Character.SeleneMethods.GetPlayerLanguage = Character.SeleneMethods.getPlayerLanguage

Character.SeleneMethods.isNewPlayer = function(user)
    local playerData = user.SelenePlayer and user.SelenePlayer:getRuntimeData(DataKeys.Player) or nil
    return playerData and (playerData[DataFields.TotalOnlineTime] or 0) < 10 * 60 * 60 or false
end

Character.SeleneMethods.idleTime = function(user)
    return user.SelenePlayer and user.SelenePlayer:getIdleTime() or 0
end

Character.SeleneMethods.logAdmin = function(user, message)
    local isAdmin = user:isAdmin()
    EventLog.logAdmin(user, message, isAdmin)
    local playerTypePrefix = isAdmin and "Admin" or "Player"
    print("[Admin]", playerTypePrefix, user.name, "(" .. user.id .. ")", "uses admin tool:", message)
end

Character.SeleneMethods.sendCharDescription = function(user, id, description)
    id = assert(tonumber(id), "id must be a number, was " .. tostring(id))
    local target = Entities.findByRuntimeData(DataKeys.Character, DataFields.ID, id)
    if target then
        Network.sendToEntity(user.SeleneEntity, "illarion:look_at_entity", {
            networkId = target:getNetworkId(),
            tooltip = {
                name = description
            }
        })
    end
end

function Character.fromSelenePlayer(player)
    if not player:getControlledEntity() then
        print(debug.traceback())
        error("fromSelenePlayer called before the player had a controlled entity")
    end
    return setmetatable({SelenePlayer = player}, Character.SeleneMetatable)
end
