-- Run from the repository root: lua bundles/illarion-script-loader/tests/behavior_init_test.lua
local Behaviors = dofile('bundles/moonlight/moonlight-behaviors/server/lua/behaviors.lua')
package.loaded['moonlight-behaviors.server.lua.behaviors'] = Behaviors
for _, kind in ipairs({'areas', 'triggerfields'}) do
    local calls, signals = {}, {}
    local function signal(name)
        signals[name] = {connect=function(self, callback) self.callback=callback end}
        return signals[name]
    end
    local definition = {enabled=true, coordinate={x=1,y=2,z=0},
        behaviors={{event='init',actions={{type='record'}}}}}
    local entry = {getField=function(_, key) return definition[key] end,
        getName=function() return 'illarion:test' end}
    package.loaded['illarion-script-loader.server.lua.lib.behaviorDefaults'] = {
        registerBehaviorDefaults=function(behaviors)
            return behaviors:registerAction('record', function(_, context)
                assert(context.character == nil)
                if kind == 'areas' then
                    assert(context.area == entry)
                else
                    assert(context.triggerfield == entry and context.coordinate == definition.coordinate)
                    assert(signals.annotation.triggerfield == entry:getName())
                end
                calls[#calls+1] = context
            end)
        end,
    }
    package.loaded['selene.registries'] = {
        findAll=function(registry) assert(registry == 'illarion:' .. kind); return {entry} end,
        entryAdded=function() return signal('added') end,
        entryChanged=function() return signal('changed') end,
        entryRemoved=function() return signal('removed') end,
        reloaded=function() return signal('registryReloaded') end,
    }
    package.loaded['selene.server'] = {serverReloaded=signal('serverReloaded')}
    package.loaded['selene.entities'] = {steppedOnTile=signal('on'), steppedOffTile=signal('off')}
    package.loaded['selene.dimensions'] = {getDefault=function() return {
        getMap=function() return {annotateTile=function(_, x,y,z,key,value) signals.annotation=value end} end,
    } end}
    local path = kind == 'areas' and 'bundles/illarion-gobaith/server/lua/base/areas.lua'
        or 'bundles/illarion-script-loader/server/lua/triggerfields.lua'
    dofile(path)
    assert(#calls == 1, kind .. ' must initialize on load')
    for _, name in ipairs({'serverReloaded','registryReloaded','added','changed','removed'}) do
        local count = #calls
        signals[name].callback()
        assert(#calls == count + 1, kind .. ' must initialize on ' .. name)
        definition.enabled = false
        signals[name].callback()
        assert(#calls == count + 1, 'Disabled ' .. kind .. ' must not initialize')
        definition.enabled = true
    end
end
print('behavior init tests passed')
