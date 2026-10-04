local Environment = require("selene.environment")
local Players = require("selene.players")
local Schedules = require("selene.schedules")

local Events = require("illarion-script-loader.server.lua.lib.events")

local UPDATE_INTERVAL_MS = 10 * 1000

local colors = {
    {{.20,.20,.40},{.15,.15,.20}}, {{.15,.15,.30},{.10,.10,.15}},
    {{.15,.15,.30},{.10,.10,.15}}, {{.15,.15,.30},{.20,.20,.30}},
    {{.70,.70,.75},{.40,.40,.45}}, {{1,.95,.80},{.60,.60,.60}},
    {{1,.98,.90},{.70,.70,.70}}, {{1,1,1},{.80,.80,.80}},
    {{1,1,1},{.80,.80,.80}}, {{1,1,1},{.80,.80,.80}},
    {{1,1,1},{.80,.80,.80}}, {{1,1,1},{.80,.80,.80}},
    {{1,1,1},{.80,.80,.80}}, {{1,1,1},{.80,.80,.80}},
    {{1,1,1},{.80,.80,.80}}, {{1,1,1},{.80,.80,.80}},
    {{1,1,1},{.80,.80,.80}}, {{1,1,1},{.80,.80,.80}},
    {{1,1,1},{.80,.80,.80}}, {{1,.90,.80},{.70,.70,.70}},
    {{1,.80,.70},{.60,.60,.60}}, {{.70,.60,.70},{.40,.40,.45}},
    {{.20,.20,.40},{.20,.20,.30}}, {{.20,.20,.40},{.15,.15,.20}}
}

local function lerp(a, b, alpha)
    return a + (b - a) * alpha
end

local function calculateLight()
    local hour = world:getTime("hour")
    local minuteAlpha = (world:getTime("minute") + world:getTime("second") / 60) / 60
    local current = colors[hour + 1]
    local following = colors[(hour + 1) % 24 + 1]
    local cloudAlpha = math.min(math.max((world.weather.cloud_density or 0) / 60, 0), 1)
    local result = {}
    for channel = 1, 3 do
        local clear = lerp(current[1][channel], following[1][channel], minuteAlpha)
        local cloudy = lerp(current[2][channel], following[2][channel], minuteAlpha)
        result[channel] = lerp(clear, cloudy, cloudAlpha)
    end
    return { red = result[1], green = result[2], blue = result[3] }
end

local function updatePlayer(player)
    Environment.setAmbientLight(player, calculateLight())
end

local function updateAll()
    Environment.setGlobalAmbientLight(calculateLight())
end

Players.playerJoined:connect(updatePlayer)
Events.onWeatherChanged:connect(updateAll)
Schedules.setInterval(UPDATE_INTERVAL_MS, updateAll)
