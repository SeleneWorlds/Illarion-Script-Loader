-- Run from the repository root: lua bundles/illarion-script-loader/tests/rotting_tiles.lua
local fields = { Wear = 'wear' }
local defs = {}
local function definition(id, aging, replacement)
    local def = { id = id, aging = aging, replacement = replacement }
    function def:getMetadata() return self.id end
    function def:getField(key)
        if key == 'objectAfterRot' then return self.replacement end
    end
    defs[id] = def
    return def
end
definition(1, 3, 'replacement')
definition(2, 7)
definition(3, 255)
local tileDefs = {}
for id = 1, 3 do
    tileDefs[id] = { getName = function() return 'tile' .. id end }
end
local annotations, tiles, removed, swapped, notifications
local dim = {}
function dim:getAnnotationAt(_, key) return annotations[key] end
function dim:annotateTile(_, key, data) annotations[key] = data end
function dim:getMap() return self end
function dim:removeTile() removed = true end
function dim:swapTile(_, _, def) swapped = def; tiles = { makeTile(2) } end
function dim:getTilesAt() return tiles end
function dim:getAllAnnotations()
    return { { coordinate = {}, annotations = annotations } }
end
function makeTile(id)
    return {
        getDimension = function() return dim end,
        hasTag = function() return true end,
        getMetadata = function() return id end,
        getCoordinate = function() return {} end,
        getName = function() return 'tile' .. id end,
        getDefinition = function() return tileDefs[id] end
    }
end
package.loaded['selene.dimensions'] = { getDefault = function() return dim end }
package.loaded['selene.entities'] = { findAllByTag = function() return {} end }
package.loaded['selene.players'] = { getOnlinePlayers = function() return {} end }
package.loaded['selene.registries'] = {
    findByMetadata = function(registry, _, id)
        return registry == 'tiles' and tileDefs[id] or defs[id]
    end,
    findByName = function() return defs[2] end
}
package.loaded['illarion-script-loader.server.lua.lib.dataFields'] = fields
package.loaded['illarion-script-loader.server.lua.lib.itemEntity'] = {}
package.loaded['illarion-script-loader.server.lua.lib.datakeys'] = {}
package.loaded['illarion-script-loader.server.lua.lib.inventoryManager'] = {
    InitialWear = function(def) return def.aging end
}
Item = { fromSeleneTile = function(tile) return tile end, fromSeleneEmpty = function() return {} end }
package.loaded['test.trigger'] = { ItemRotsOnField = function(old, replacement)
    notifications = { old, replacement }
end }
local manager = dofile('bundles/illarion-script-loader/server/lua/lib/rottingManager.lua')
local function reset(id, wear)
    annotations = { ['tile' .. id] = { wear = wear, quality = 123, custom = 'kept' },
        ['illarion:triggerfield'] = { script = 'test.trigger' } }
    tiles = { makeTile(id) }
    removed, swapped, notifications = nil, nil, nil
end
reset(1, 2)
manager.Tick()
assert(annotations.tile1.wear == 1)
assert(not swapped and not removed)
manager.Tick()
assert(swapped == tileDefs[2])
assert(annotations.tile1 == nil and annotations.tile2.wear == 7)
assert(annotations.tile2.quality == 123 and annotations.tile2.custom == 'kept')
assert(notifications[1]:getMetadata() == 1 and notifications[2]:getMetadata() == 2)
reset(2, 1)
manager.Tick()
assert(removed and annotations.tile2 == nil and notifications)
reset(3, 255)
manager.Tick()
assert(annotations.tile3.wear == 255 and not removed and not swapped)
reset(1, nil)
manager.Tick()
assert(annotations.tile1.wear == 2)
annotations.tile1 = nil
manager.Tick()
assert(not removed and not swapped)
print('Tile rotting tests passed')
