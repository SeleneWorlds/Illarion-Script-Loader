-- Run from the repository root: lua bundles/illarion-script-loader/tests/item_conditions_test.lua
package.loaded['selene.registries'] = {findByName=function(registry, name)
    assert(registry == 'illarion:items')
    if name == 'illarion:item_52' then return {getMetadata=function(_, key) assert(key=='id'); return 52 end} end
end}
package.loaded['illarion-script-loader.server.lua.lib.inventoryManager'] = {}
local Behaviors = dofile('bundles/moonlight/moonlight-behaviors/server/lua/behaviors.lua')
package.loaded['moonlight-behaviors.server.lua.behaviors'] = Behaviors
local defaults = dofile('bundles/illarion-script-loader/server/lua/lib/behaviorDefaults.lua')
local behaviors = defaults.registerBehaviorDefaults(Behaviors:new())
-- Use the real door classification helpers.
package.loaded['base.common'] = {}
package.loaded['base.doors'] = dofile('bundles/illarion-gobaith/server/lua/base/doors.lua')
local item, calls
position = function(x,y,z) return {x=x,y=y,z=z} end
world = {getItemOnField=function(_, pos)
    assert(pos.x == -74 and pos.y == -68 and pos.z == 0)
    return item
end}
behaviors:registerAction('record', function() calls=calls+1 end)
local coordinate = {x=-74,y=-68,z=0}
local function check(kind, expected)
    calls = 0
    behaviors:run({conditions={{type=kind, data={position=coordinate,item='illarion:item_52'}}},
        actions={{type='record'}}}, {})
    assert(calls == (expected and 1 or 0), kind)
end
for _, case in ipairs({
    {item={id=497,quality=333},closed=true,locked=true},
    {item={id=497,quality=233},closed=true,locked=false},
    {item={id=86,quality=333},closed=false,locked=false},
    {item={id=52,quality=333},closed=false,locked=false,match=true},
    {item={id=51,quality=233},closed=false,locked=false},
    {closed=false,locked=false},
}) do
    item = case.item
    check('is_door_closed',case.closed)
    check('is_door_locked',case.locked)
    check('is_item_at',case.match == true)
end
local invalid = {type='is_item_at',data={position=coordinate,item='illarion:unknown'}}
assert(not pcall(behaviors.run, behaviors, {conditions={invalid},actions={}}, {}))
invalid.data.item = nil
assert(not pcall(behaviors.run, behaviors, {conditions={invalid},actions={}}, {}))
local variants = defaults.schema().conditions.valueType.properties.data.variants
for _, kind in ipairs({'is_door_closed','is_door_locked','is_item_at'}) do
    assert(variants[kind].properties.position == 'coordinate')
end
assert(variants.is_item_at.properties.item.registry == 'illarion:items')
print('item condition tests passed')
