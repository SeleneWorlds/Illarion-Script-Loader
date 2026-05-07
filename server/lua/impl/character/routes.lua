local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local Pathfinding = require("selene.pathfinding")

Character.SeleneMethods.getNextStepDir = function(user, goal)
    local path = Pathfinding.findPath(user.SeleneEntity, goal)
    if path == nil then
        return nil
    end

    local step = path[1]
    if step == nil then
        return nil
    end

    return DirectionUtils.SeleneToIlla(step.name)
end

Character.SeleneMethods.getStepList = function(user, goal)
    local path = Pathfinding.findPath(user.SeleneEntity, goal)
    if path == nil then
        return nil
    end

    local result = {}
    for index, step in ipairs(path) do
        result[index] = DirectionUtils.SeleneToIlla(step.name)
    end
    return result
end
