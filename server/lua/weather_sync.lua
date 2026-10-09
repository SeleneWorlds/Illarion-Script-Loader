local Network = require("selene.network")
local Players = require("selene.players")
local Schedules = require("selene.schedules")
local Timelines = require("selene.timelines")

local Events = require("illarion-script-loader.server.lua.lib.events")

local PAYLOAD_ID = "illarion:weather"
local RESYNC_INTERVAL_MS = 60 * 1000
local RAIN_TIMELINE = "illarion:weather/rain"
local FOG_TIMELINE = "illarion:weather/fog"
local SNOW_TIMELINE = "illarion:weather/snow"
local PRECIPITATION_INSTANCE = "weather-precipitation"
local FOG_INSTANCE = "weather-fog"
local WEATHER_TRANSITION_SECONDS = 2
local PRECIPITATION_TIMELINE_KEY = "illarion:weather/precipitation_timeline"
local LIGHTNING_TIMELINE = "illarion:weather/lightning"
local LIGHTNING_CHECK_INTERVAL_MS = 1000
local LIGHTNING_CHANCE_SCALE = 1000

local function getPrecipitationTimeline(weather)
    if (weather.percipitation_strength or 0) <= 0 then
        return nil
    end
    if weather.percipitation_type == 1 then
        return RAIN_TIMELINE
    end
    if weather.percipitation_type == 2 then
        return SNOW_TIMELINE
    end
    return nil
end

local function updateWeatherEffects(player, weather)
    local timeline = getPrecipitationTimeline(weather)
    local precipitationStrength = math.min(math.max((weather.percipitation_strength or 0) / 100, 0), 1)
    local activeTimeline = player[PRECIPITATION_TIMELINE_KEY]
    if timeline and timeline ~= activeTimeline then
        -- New emitters start at zero; replacing the instance lets old particles finish.
        Timelines.play(player, timeline, { precipitationStrength = 0 }, nil, {
            instanceId = PRECIPITATION_INSTANCE
        })
        player[PRECIPITATION_TIMELINE_KEY] = timeline
        activeTimeline = timeline
    end
    if activeTimeline then
        Timelines.play(player, activeTimeline, {
            precipitationStrength = timeline and precipitationStrength or 0
        }, nil, {
            instanceId = PRECIPITATION_INSTANCE,
            transition = WEATHER_TRANSITION_SECONDS
        })
    end
    local fogDensity = math.min(math.max((weather.fog_density or 0) / 100, 0), 1)
    Timelines.play(player, FOG_TIMELINE, { fogDensity = fogDensity }, nil, {
        instanceId = FOG_INSTANCE,
        transition = WEATHER_TRANSITION_SECONDS
    })
end

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
    local weather = createWeatherPayload()
    Network.sendToPlayer(player, PAYLOAD_ID, weather)
    updateWeatherEffects(player, weather)
end

local function broadcastWeather(weather)
    for _, player in ipairs(Players.getOnlinePlayers()) do
        Network.sendToPlayer(player, PAYLOAD_ID, weather)
        updateWeatherEffects(player, weather)
    end
end

Network.handlePayload("illarion:request_weather", function(player)
    sendWeather(player)
end)

Players.playerJoined:connect(function(player)
    Timelines.play(player, FOG_TIMELINE, { fogDensity = 0 }, nil, { instanceId = FOG_INSTANCE })
    sendWeather(player)
end)
Events.onWeatherChanged:connect(broadcastWeather)

Schedules.setInterval(RESYNC_INTERVAL_MS, function()
    broadcastWeather(createWeatherPayload())
end)

Schedules.setInterval(LIGHTNING_CHECK_INTERVAL_MS, function()
    local thunderstorm = math.min(math.max(world.weather.thunderstorm or 0, 0), 100)
    if thunderstorm <= 0 or math.random(LIGHTNING_CHANCE_SCALE) > thunderstorm then
        return
    end
    for _, player in ipairs(Players.getOnlinePlayers()) do
        Timelines.play(player, LIGHTNING_TIMELINE)
    end
end)
