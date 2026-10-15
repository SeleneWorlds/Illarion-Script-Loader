-- Run from the repository root: lua bundles/illarion-script-loader/tests/door_behaviors_test.lua
package.loaded['selene.registries'] = {}
package.loaded['illarion-script-loader.server.lua.lib.inventoryManager'] = {}
local Behaviors = dofile('bundles/moonlight/moonlight-behaviors/server/lua/behaviors.lua')
package.loaded['moonlight-behaviors.server.lua.behaviors'] = Behaviors
local defaults = dofile('bundles/illarion-script-loader/server/lua/lib/behaviorDefaults.lua')
local behaviors = defaults.registerBehaviorDefaults(Behaviors:new())
local calls, closed = {}, false
position = function(x,y,z) return {x=x,y=y,z=z} end
Character = {}
local directions = {'north','northeast','east','southeast','south','southwest','west','northwest'}
for index, direction in ipairs(directions) do Character[direction] = index - 1 end
world = {getItemOnField=function(_, pos)
    assert(pos.x == -74 and pos.y == -68 and pos.z == 0)
    return {closed=closed}
end}
package.loaded['base.doors'] = {CloseDoor=function(item)
    assert(not item.closed)
    closed = true
    calls[#calls+1] = 'close'
end}
package.loaded['base.keys'] = {LockDoor=function(item)
    assert(item.closed, 'Lock must fetch the updated door after closing')
    calls[#calls+1] = 'lock'
end}
local facing = Character.east
local context = {character={get_face_to=function() return facing end}}
local definition = {event='move_to_field', conditions={{type='is_facing',data={direction='east'}}}, actions={
    {type='close_door',data={position={x=-74,y=-68,z=0}}},
    {type='lock_door',data={position={x=-74,y=-68,z=0}}},
}}
for _, direction in ipairs(directions) do
    facing = Character[direction]
    calls, closed = {}, false
    behaviors:emit('move_to_field',{definition},context)
    assert(table.concat(calls,',') == (direction == 'east' and 'close,lock' or ''))
end
definition.conditions[1].data.direction = 'invalid'
assert(not pcall(behaviors.emit, behaviors, 'move_to_field', {definition}, context))
local schema = defaults.schema()
for _, action in ipairs({'close_door','lock_door'}) do
    assert(schema.actions.valueType.properties.data.variants[action].properties.position == 'coordinate')
end
local facingSchema = schema.conditions.valueType.properties.data.variants.is_facing.properties.direction
assert(facingSchema.type == 'enum' and #facingSchema.values == 8)
print('door behavior tests passed')
