local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local m = {}

local SEARCH_RADIUS = 32

local directions = {
    { dx = 0, dy = -1, dir = Character.north },
    { dx = 1, dy = -1, dir = Character.northeast },
    { dx = 1, dy = 0, dir = Character.east },
    { dx = 1, dy = 1, dir = Character.southeast },
    { dx = 0, dy = 1, dir = Character.south },
    { dx = -1, dy = 1, dir = Character.southwest },
    { dx = -1, dy = 0, dir = Character.west },
    { dx = -1, dy = -1, dir = Character.northwest }
}

local function clonePosition(pos)
    return position(pos.x, pos.y, pos.z)
end

local function samePosition(a, b)
    return a ~= nil and b ~= nil and a.x == b.x and a.y == b.y and a.z == b.z
end

local function positionKey(pos)
    return table.concat({ pos.x, pos.y, pos.z }, ":")
end

local function heuristic(a, b)
    return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

local function getState(character)
    local entity = character.SeleneEntity
    local state = entity:getRuntimeData(DataKeys.Route)
    if not state then
        state = {
            onRoute = false,
            waypoints = {},
            currentPath = nil,
            currentGoal = nil
        }
    end
    return state
end

local function invalidatePath(state)
    state.currentPath = nil
    state.currentGoal = nil
end

local function normalizePosition(pos)
    if pos == nil then
        error("Waypoint position must not be nil")
    end
    return position(pos.x, pos.y, pos.z)
end

local function popReachedWaypoints(currentPos, state)
    local removed = false
    while #state.waypoints > 0 and samePosition(currentPos, state.waypoints[1]) do
        table.remove(state.waypoints, 1)
        removed = true
    end
    if removed then
        invalidatePath(state)
    end
end

local function reconstructPath(cameFrom, goalKey)
    local path = {}
    local currentKey = goalKey
    while cameFrom[currentKey] do
        local step = cameFrom[currentKey]
        table.insert(path, 1, step.dir)
        currentKey = step.parentKey
    end
    return path
end

local function canVisit(character, candidate, goal)
    if samePosition(candidate, goal) then
        return true
    end
    local dimension = character.SeleneEntity:getDimension()
    if dimension == nil then
        return false
    end
    return not dimension:hasCollisionAt(candidate, character.SeleneEntity.Collision)
end

local function findPath(character, goal)
    local start = clonePosition(character.pos)
    if samePosition(start, goal) then
        return {}
    end

    local open = { start }
    local openSet = { [positionKey(start)] = true }
    local cameFrom = {}
    local gScore = { [positionKey(start)] = 0 }
    local fScore = { [positionKey(start)] = heuristic(start, goal) }

    while #open > 0 do
        local bestIndex = 1
        local bestNode = open[1]
        local bestScore = fScore[positionKey(bestNode)] or math.huge
        for i = 2, #open do
            local candidate = open[i]
            local candidateScore = fScore[positionKey(candidate)] or math.huge
            if candidateScore < bestScore then
                bestIndex = i
                bestNode = candidate
                bestScore = candidateScore
            end
        end

        table.remove(open, bestIndex)
        local bestKey = positionKey(bestNode)
        openSet[bestKey] = nil

        if samePosition(bestNode, goal) then
            return reconstructPath(cameFrom, bestKey)
        end

        local baseCost = gScore[bestKey] or math.huge
        for _, step in ipairs(directions) do
            local nextPos = position(bestNode.x + step.dx, bestNode.y + step.dy, bestNode.z)
            if heuristic(start, nextPos) <= SEARCH_RADIUS and canVisit(character, nextPos, goal) then
                local nextKey = positionKey(nextPos)
                local tentativeCost = baseCost + 1
                if tentativeCost < (gScore[nextKey] or math.huge) then
                    cameFrom[nextKey] = {
                        parentKey = bestKey,
                        dir = step.dir
                    }
                    gScore[nextKey] = tentativeCost
                    fScore[nextKey] = tentativeCost + heuristic(nextPos, goal)
                    if not openSet[nextKey] then
                        table.insert(open, nextPos)
                        openSet[nextKey] = true
                    end
                end
            end
        end
    end

    return nil
end

local function ensurePath(character, state)
    popReachedWaypoints(character.pos, state)
    local goal = state.waypoints[1]
    if goal == nil then
        return false, "complete"
    end

    if state.currentPath == nil or state.currentGoal == nil or not samePosition(state.currentGoal, goal) then
        local path = findPath(character, goal)
        if path == nil then
            invalidatePath(state)
            return false, "blocked"
        end
        state.currentPath = path
        state.currentGoal = clonePosition(goal)
    end

    return true
end

function m.GetState(character)
    return getState(character)
end

function m.SetOnRoute(character, onRoute)
    local state = getState(character)
    state.onRoute = onRoute and true or false
    if not state.onRoute then
        invalidatePath(state)
    end
end

function m.GetOnRoute(character)
    return getState(character).onRoute
end

function m.AddWaypoint(character, pos)
    local state = getState(character)
    table.insert(state.waypoints, normalizePosition(pos))
    invalidatePath(state)
end

function m.AddFromList(character, positions)
    if type(positions) ~= "table" then
        return
    end
    for _, pos in ipairs(positions) do
        m.AddWaypoint(character, pos)
    end
end

function m.GetWaypoints(character)
    local waypoints = {}
    local state = getState(character)
    for i, waypoint in ipairs(state.waypoints) do
        waypoints[i] = clonePosition(waypoint)
    end
    return waypoints
end

function m.Clear(character)
    local state = getState(character)
    state.waypoints = {}
    invalidatePath(state)
end

function m.Advance(character)
    local state = getState(character)
    if not state.onRoute then
        return "idle"
    end

    local ready, status = ensurePath(character, state)
    if not ready then
        return status
    end

    if #state.currentPath == 0 then
        popReachedWaypoints(character.pos, state)
        if #state.waypoints == 0 then
            invalidatePath(state)
            return "complete"
        end
        invalidatePath(state)
        return m.Advance(character)
    end

    local step = table.remove(state.currentPath, 1)
    local moved = character.SeleneEntity:move(DirectionUtils.IllaToSelene(step))
    if not moved then
        invalidatePath(state)
        local retryReady, retryStatus = ensurePath(character, state)
        if not retryReady or #state.currentPath == 0 then
            return retryStatus or "blocked"
        end
        step = table.remove(state.currentPath, 1)
        moved = character.SeleneEntity:move(DirectionUtils.IllaToSelene(step))
        if not moved then
            invalidatePath(state)
            return "blocked"
        end
    end

    popReachedWaypoints(character.pos, state)
    if #state.waypoints == 0 then
        invalidatePath(state)
        return "complete"
    end
    if #state.currentPath == 0 then
        invalidatePath(state)
    end
    return "moving"
end

return m
