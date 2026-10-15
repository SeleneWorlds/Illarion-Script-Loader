-- Run from the repository root: lua bundles/illarion-script-loader/tests/speech_warp_behaviors_test.lua
package.loaded['selene.registries'] = {}
package.loaded['illarion-script-loader.server.lua.lib.inventoryManager'] = {}
local Behaviors = dofile('bundles/moonlight/moonlight-behaviors/server/lua/behaviors.lua')
package.loaded['moonlight-behaviors.server.lua.behaviors'] = Behaviors
local defaults = dofile('bundles/illarion-script-loader/server/lua/lib/behaviorDefaults.lua')
local behaviors = defaults.registerBehaviorDefaults(Behaviors:new())
local calls = 0
position = function(x,y,z) return {x=x,y=y,z=z, isPosition=true} end
local character = {warp=function(_, pos)
    assert(pos.isPosition and pos.x == -72 and pos.y == -67 and pos.z == -3)
    calls = calls + 1
    return 'warped'
end}
local condition = {type='last_spoken_contains', data={phrase='Open Sesame'}}
local definition = {conditions={condition}, actions={{type='warp', data={position={x=-72,y=-67,z=-3}}}}}
local function check(text, phrase, ignoreCase, expected)
    character.lastSpokenText = text
    condition.data = {phrase=phrase,ignoreCase=ignoreCase}
    calls = 0
    local result = behaviors:run(definition, {character=character})
    assert(calls == (expected and 1 or 0))
    if expected then assert(result[1].value == 'warped') end
end
check('Please Open Sesame now', 'Open Sesame', nil, true)
check('Please OPEN SESAME now', 'Open Sesame', nil, false)
check('Please OPEN SESAME now', 'Open Sesame', false, false)
check('Please OPEN SESAME now', 'Open Sesame', true, true)
check('Please open sesame now', 'OPEN SESAME', true, true)
check('password', 'missing', true, false)
check('say a.b%[ now', 'a.b%[', false, true)
check('say axb now', 'a.b', false, false)
check(nil, 'password', true, false)
check('', 'password', false, false)
check('anything', '', false, true)
for _, payload in ipairs({{phrase=42}, {phrase='test',ignoreCase='true'}}) do
    condition.data = payload
    calls = 0
    assert(not pcall(behaviors.run, behaviors, definition, {character=character}))
    assert(calls == 0)
end
local schema = defaults.schema()
assert(schema.actions.valueType.properties.data.variants.warp.properties.position == 'coordinate')
local properties = schema.conditions.valueType.properties.data.variants.last_spoken_contains.properties
assert(properties.phrase == 'string')
assert(properties.ignoreCase.type == 'boolean' and properties.ignoreCase.optional)
print('speech and warp behavior tests passed')
