local Server = require("selene.server")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

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

world.SeleneMethods.setWeather = function(world, weather)
    world.weather = weather
end

world.SeleneGetters.weather = function(world)
    return Server.CustomData[DataKeys.Weather] or defaultWeather
end

world.SeleneSetters.weather = function(world, weather)
    Server.CustomData[DataKeys.Weather] = {
        cloud_density = weather.cloud_density or defaultWeather.cloud_density,
        fog_density = weather.fog_density or defaultWeather.fog_density,
        wind_dir = weather.wind_dir or defaultWeather.wind_dir,
        gust_strength = weather.gust_strength or defaultWeather.gust_strength,
        percipitation_strength = weather.percipitation_strength or defaultWeather.percipitation_strength,
        percipitation_type = weather.percipitation_type or defaultWeather.percipitation_type,
        thunderstorm = weather.thunderstorm or defaultWeather.thunderstorm,
        temperature = weather.temperature or defaultWeather.temperature
    }
end