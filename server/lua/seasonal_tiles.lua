local Json = require("selene.json")
local Registries = require("selene.registries")
local Resources = require("selene.resources")
local Schedules = require("selene.schedules")

local GRASS_TILE_ID = 11
local SNOW_TILE_ID = 10
local UPDATE_INTERVAL_MS = 20 * 1000
local appliedWinter
local updating = false

local function readDefinition(tile)
    local path = tile:getSourcePath()
    if not path then
        return nil
    end
    local definition = Json.decode(Resources.loadAsString(path))
    if definition.entries then
        local entryName = tile:getName():match("^[^:]+:(.+)$")
        return definition.entries[entryName]
    end
    return definition
end

local function update(force)
    if updating then
        return
    end
    local month = world:getTime("month")
    local winter = month >= 13 and month <= 16
    if not force and appliedWinter == winter then
        return
    end

    local grassTiles = {}
    local snowTiles = {}
    for _, tile in pairs(Registries.findAll("tiles")) do
        local tileId = tile:getMetadata("tileId")
        if tileId == GRASS_TILE_ID then
            grassTiles[#grassTiles + 1] = tile
        elseif tileId == SNOW_TILE_ID then
            snowTiles[tile:getMetadata("overlayId") or 0] = tile
        end
    end

    updating = true
    local complete = #grassTiles > 0
    local ok, err = pcall(function()
        for _, grass in ipairs(grassTiles) do
            local definition = readDefinition(grass)
            local snow = snowTiles[grass:getMetadata("overlayId") or 0]
            local snowDefinition = winter and snow and readDefinition(snow)
            if definition and (not winter or snowDefinition) then
                if winter then
                    definition.visual = snowDefinition.visual
                end
                Registries.add("tiles", grass:getName(), definition)
            else
                complete = false
            end
        end
    end)
    updating = false
    if not ok then
        error(err)
    end
    if complete then
        appliedWinter = winter
    else
        appliedWinter = nil
    end
end

Registries.reloaded("tiles"):connect(function()
    update(true)
end)
Registries.entryChanged("tiles"):connect(function(_, _, tile)
    local tileId = tile:getMetadata("tileId")
    if tileId == GRASS_TILE_ID or tileId == SNOW_TILE_ID then
        update(true)
    end
end)
Schedules.setInterval(UPDATE_INTERVAL_MS, function()
    update(false)
end)
update(true)
