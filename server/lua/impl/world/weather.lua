local Server = require("selene.server")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local Events = require("illarion-script-loader.server.lua.lib.events")

local defaultWeather = {
    cloud_density = 20,
    fog_density = 0,
    wind_dir = 50,
    gust_strength = 10,
    percipitation_strength = 0,
    percipitation_type = 0,
    thunderstorm = 0,
    temperature = 20
}

local function normalizeWeather(weather)
    weather = weather or {}
    return {
        cloud_density = weather.cloud_density == nil and defaultWeather.cloud_density or weather.cloud_density,
        fog_density = weather.fog_density == nil and defaultWeather.fog_density or weather.fog_density,
        wind_dir = weather.wind_dir == nil and defaultWeather.wind_dir or weather.wind_dir,
        gust_strength = weather.gust_strength == nil and defaultWeather.gust_strength or weather.gust_strength,
        percipitation_strength = weather.percipitation_strength == nil
            and defaultWeather.percipitation_strength or weather.percipitation_strength,
        percipitation_type = weather.percipitation_type == nil
            and defaultWeather.percipitation_type or weather.percipitation_type,
        thunderstorm = weather.thunderstorm == nil and defaultWeather.thunderstorm or weather.thunderstorm,
        temperature = weather.temperature == nil and defaultWeather.temperature or weather.temperature
    }
end

world.SeleneMethods.setWeather = function(world, weather)
    world.weather = weather
end

world.SeleneGetters.weather = function(world)
    return normalizeWeather(Server.getRuntimeData(DataKeys.Weather))
end

world.SeleneSetters.weather = function(world, weather)
    local updatedWeather = normalizeWeather(weather)
    Server.overwriteRuntimeData(DataKeys.Weather, updatedWeather)
    Events.onWeatherChanged:fire(updatedWeather)
end
