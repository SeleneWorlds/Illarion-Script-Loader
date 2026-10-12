package.path = "bundles/?.lua;" .. package.path
local prefix = "illarion-script-loader.server.lua.lib."
local DataKeys = require(prefix .. "datakeys")
local DataFields = require(prefix .. "dataFields")
local active = {}
package.loaded["selene.entities"] = {
    activeByTag = function() return active end,
    byTag = function() error("AI must not scan sleeping entities") end,
}
package.loaded["selene.registries"] = {}
package.loaded["selene.grid"] = { getDirections = function() return {} end }
package.loaded["selene.pathfinding"] = {}
package.loaded[prefix .. "constants"] = {}
package.loaded[prefix .. "characterManager"] = {}
package.loaded[prefix .. "directionUtils"] = {}
package.loaded[prefix .. "combatManager"] = {}
Character = { monster = 2, fromSeleneEntity = function(entity) return { SeleneEntity = entity } end }

local reads, movementChecks = 0, 0
local function entity()
    local data = {
        [DataKeys.Character] = {
            [DataFields.CharacterType] = Character.monster,
            [DataFields.ActionPoints] = 21,
            [DataFields.FightPoints] = 0,
        },
        [DataKeys.Route] = { onRoute = false, waypoints = {} },
    }
    return {
        data = data,
        enabled = true,
        getRuntimeData = function(_, key) reads = reads + 1; return data[key] end,
        isMoving = function() movementChecks = movementChecks + 1; return false end,
        isActive = function(self) return self.enabled end,
        setKeepAwake = function(self, value) self.keepAwake = value end,
    }
end

local MonsterManager = require(prefix .. "monsterManager")
local RouteManager = require(prefix .. "routeManager")
local sleeping = entity()
for _ = 1, 100 do MonsterManager.Update() end
assert(reads == 0 and movementChecks == 0)
assert(sleeping.data[DataKeys.Character][DataFields.FightPoints] == 0)

local first, second = entity(), entity()
active = { first, second }
-- Membership can change during a hook without dropping the next entity's update.
local moving = first.isMoving
first.isMoving = function() active[1] = nil; active[2] = nil; return moving() end
MonsterManager.Update()
assert(first.data[DataKeys.Character][DataFields.FightPoints] == 1)
assert(second.data[DataKeys.Character][DataFields.FightPoints] == 1)

active = { sleeping }
MonsterManager.Update()
assert(sleeping.data[DataKeys.Character][DataFields.FightPoints] == 1)
sleeping.enabled = false
MonsterManager.Update()
assert(sleeping.data[DataKeys.Character][DataFields.FightPoints] == 1)

local character = { SeleneEntity = sleeping }
RouteManager.SetOnRoute(character, true)
assert(sleeping.keepAwake and RouteManager.GetOnRoute(character))
RouteManager.SetOnRoute(character, false)
assert(not sleeping.keepAwake and not RouteManager.GetOnRoute(character))
print("Activation integration tests passed")
