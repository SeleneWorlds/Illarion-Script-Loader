-- Run from the repository root: lua bundles/illarion-script-loader/tests/triggerfield_behaviors_test.lua
package.loaded['moonlight-behaviors.server.lua.behaviors'] = dofile('bundles/moonlight/moonlight-behaviors/server/lua/behaviors.lua')
package.loaded['illarion-script-loader.server.lua.lib.inventoryManager'] = {}
local function signal()
    return {connect=function(self, callback) self.callback = callback end}
end
local entities = {steppedOnTile=signal(), steppedOffTile=signal()}
local reload = signal()
local definition = {enabled=true, coordinate={x=1,y=2,z=0}, behaviors={}}
local entry = {getField=function(_, key) return definition[key] end, getName=function() return 'illarion:test' end}
package.loaded['selene.registries'] = {
    findAll=function() return {entry} end,
    findByName=function() return entry end,
    entryAdded=function() return signal() end,
    entryChanged=function() return signal() end,
    entryRemoved=function() return signal() end,
    reloaded=function() return signal() end,
}
package.loaded['illarion-script-loader.server.lua.lib.behaviorDefaults'] = dofile('bundles/illarion-script-loader/server/lua/lib/behaviorDefaults.lua')
local annotation
local dimension = {
    getMap=function() return {annotateTile=function(_, _, _, _, _, value) annotation=value end} end,
    getAnnotationAt=function(_, _, kind, viewer)
        assert(viewer == 'viewer')
        if kind == 'illarion:triggerfield' then return annotation end
    end,
    getEntitiesAt=function() return {} end,
    getTilesAt=function() return {} end,
}
package.loaded['selene.entities'] = entities
package.loaded['selene.dimensions'] = {getDefault=function() return dimension end}
package.loaded['selene.server'] = {serverReloaded=reload}
local calls = {}
local character = {increasePoisonValue=function(_, amount) calls[#calls+1]=amount end}
Character = {fromSeleneEntity=function() return character end}
local entity = {getDimension=function() return dimension end, getCollisionViewer=function() return 'viewer' end}
local function behavior(event, amount)
    return {event=event, actions={{type='poison', data={amount=amount}}}}
end
definition.behaviors = {behavior('move_to_field',1),behavior('character_on_field',2),behavior('move_from_field',3)}
dofile('bundles/illarion-script-loader/server/lua/triggerfields.lua')
local function step()
    entities.steppedOnTile.callback(entity, definition.coordinate)
    entities.steppedOffTile.callback(entity, definition.coordinate)
end
step()
assert(table.concat(calls,',') == '1,2,3', 'Behavior-only fields must dispatch each matching event once')
calls = {}
local legacy = {}
package.preload['test.triggerfield'] = function() return {
    MoveToField=function(c,t) assert(c==character and t==entry); legacy[#legacy+1]='to' end,
    CharacterOnField=function() legacy[#legacy+1]='on' end,
    MoveFromField=function() legacy[#legacy+1]='from' end,
} end
definition.script = 'test.triggerfield'
step()
assert(table.concat(calls,',') == '1,2,3')
assert(table.concat(legacy,',') == 'to,on,from', 'Legacy callbacks must coexist with behaviors')
calls = {}
definition.behaviors = nil
step()
assert(#calls == 0, 'Legacy fields need no behaviors')
definition.script = nil
definition.behaviors = {behavior('move_to_field',4)}
step()
assert(table.concat(calls,',') == '4', 'Registry edits must be read at dispatch time')
calls = {}
definition.enabled = false
reload.callback()
step()
assert(#calls == 0, 'Disabled fields must not execute')
print('triggerfield behavior tests passed')
