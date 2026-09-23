local Network = require("selene.network")
local Players = require("selene.players")
local Schedules = require("selene.schedules")

local PAYLOAD_ID = "illarion:time"
local TIME_FACTOR = 3
local RESYNC_INTERVAL_MS = 60 * 1000

local function createTimePayload()
    local month = world:getTime("month")
    return {
        illarionTime = world:getTime("illarion"),
        timeFactor = TIME_FACTOR,
        year = world:getTime("year"),
        month = month,
        day = world:getTime("day"),
        hour = world:getTime("hour"),
        minute = world:getTime("minute"),
        second = world:getTime("second"),
        season = math.ceil(month / 4)
    }
end

local function sendTime(player)
    Network.sendToPlayer(player, PAYLOAD_ID, createTimePayload())
end

Network.handlePayload("illarion:request_time", function(player)
    sendTime(player)
end)

Schedules.setInterval(RESYNC_INTERVAL_MS, function()
    for _, player in ipairs(Players.getOnlinePlayers()) do
        sendTime(player)
    end
end)
