local Network = require("selene.network")
local Players = require("selene.players")
local Schedules = require("selene.schedules")

local Events = require("illarion-script-loader.server.lua.lib.events")

local PAYLOAD_ID = "illarion:weather"
local RESYNC_INTERVAL_MS = 60 * 1000

local function createWeatherPayload()
    local weather = world.weather
    return {
        cloud_density = weather.cloud_density,
        fog_density = weather.fog_density,
        wind_dir = weather.wind_dir,
        gust_strength = weather.gust_strength,
        percipitation_strength = weather.percipitation_strength,
        percipitation_type = weather.percipitation_type,
        thunderstorm = weather.thunderstorm,
        temperature = weather.temperature
    }
end

local function sendWeather(player)
    Network.sendToPlayer(player, PAYLOAD_ID, createWeatherPayload())
end

local function broadcastWeather(weather)
    for _, player in ipairs(Players.getOnlinePlayers()) do
        Network.sendToPlayer(player, PAYLOAD_ID, weather)
    end
end

Network.handlePayload("illarion:request_weather", function(player)
    sendWeather(player)
end)

Events.onWeatherChanged:connect(broadcastWeather)

Schedules.setInterval(RESYNC_INTERVAL_MS, function()
    broadcastWeather(createWeatherPayload())
end)
