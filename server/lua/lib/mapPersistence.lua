local Saves = require("selene.saves")
local Config = require("selene.config")
local Dimensions = require("selene.dimensions")

local M = {}
local LAYER = "edits"
local SAVE_PATH = Config.getProperty("mapEditsSavePath", "maps/edits.selenemap")

function M.initialize()
    local map = Dimensions.getDefault():getMap()
    if map:hasLayer(LAYER) then return end
    if Saves.has(SAVE_PATH) then
        map:addLayer(assert(Saves.loadMapLayer(SAVE_PATH), "Failed to load edits: " .. SAVE_PATH))
    else
        map:getLayer(LAYER)
    end
end

function M.getLayer(dimension)
    if dimension:getMap() == Dimensions.getDefault():getMap() then return LAYER end
    return nil
end

function M.save(dimension)
    if M.getLayer(dimension) then
        Saves.save(Dimensions.getDefault():getMap():getLayer(LAYER), SAVE_PATH)
    end
end

return M
