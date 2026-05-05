local RouteManager = require("illarion-script-loader.server.lua.lib.routeManager")

WaypointList.SeleneMethods.addFromList = function(waypointList, positions)
    RouteManager.AddFromList(waypointList.SeleneCharacter, positions)
end

WaypointList.SeleneMethods.addWaypoint = function(waypointList, pos)
    RouteManager.AddWaypoint(waypointList.SeleneCharacter, pos)
end

WaypointList.SeleneMethods.getWaypoints = function(waypointList)
    return RouteManager.GetWaypoints(waypointList.SeleneCharacter)
end

WaypointList.SeleneMethods.clear = function(waypointList)
    RouteManager.Clear(waypointList.SeleneCharacter)
end

function WaypointList.fromCharacter(character)
    return setmetatable({ SeleneCharacter = character }, WaypointList.SeleneMetatable)
end
