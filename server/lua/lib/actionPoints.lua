local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local M = {}
local MAX_POINTS = 21

local function clamp(value)
    value = assert(tonumber(value), "points must be a number")
    return math.max(math.mininteger, math.min(MAX_POINTS, value))
end

function M.UpdateControls(entity, data)
    local controllers = entity:getControllingPlayers()
    if #controllers == 0 then return end
    local points = data[DataFields.ActionPoints]
    for _, player in ipairs(controllers) do
        player:setCanMove(not data[DataFields.Frozen] and points >= 7)
        player:setCanTurn(points >= 1)
    end
end

function M.Initialize(data)
    if data[DataFields.ActionPoints] == nil then data[DataFields.ActionPoints] = MAX_POINTS end
    if data[DataFields.FightPoints] == nil then data[DataFields.FightPoints] = 0 end
    return data
end

function M.Data(user)
    local entity = user.SeleneEntity
    return M.Initialize(entity:getRuntimeData(DataKeys.Character))
end

function M.SetMovement(entity, data, value)
    value = clamp(value)
    if data[DataFields.ActionPoints] ~= value then
        data[DataFields.ActionPoints] = value
        M.UpdateControls(entity, data)
    end
end

function M.SetFight(data, value)
    data[DataFields.FightPoints] = clamp(value)
end

function M.Regenerate(entity, data)
    M.Initialize(data)
    if not entity:isMoving() then
        M.SetMovement(entity, data, data[DataFields.ActionPoints] + 1)
    end
    M.SetFight(data, data[DataFields.FightPoints] + 1)
    return not entity:isMoving() and data[DataFields.ActionPoints] >= MAX_POINTS
end

return M
