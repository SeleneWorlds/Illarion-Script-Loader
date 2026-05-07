local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local Pathfinding = require("selene.pathfinding")

local m = {}

local SEARCH_RADIUS = 32

local function clonePosition(pos)
    return position(pos.x, pos.y, pos.z)
end

local function samePosition(a, b)
    return a ~= nil and b ~= nil and a.x == b.x and a.y == b.y and a.z == b.z
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

local function ensurePath(character, state)
    popReachedWaypoints(character.pos, state)
    local goal = state.waypoints[1]
    if goal == nil then
        return false, "complete"
    end

    if state.currentPath == nil or state.currentGoal == nil or not samePosition(state.currentGoal, goal) then
        local path = Pathfinding.findPath(character.SeleneEntity, goal, SEARCH_RADIUS)
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
    local moved = character.SeleneEntity:move(step)
    if not moved then
        invalidatePath(state)
        local retryReady, retryStatus = ensurePath(character, state)
        if not retryReady or #state.currentPath == 0 then
            return retryStatus or "blocked"
        end
        step = table.remove(state.currentPath, 1)
        moved = character.SeleneEntity:move(step)
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
