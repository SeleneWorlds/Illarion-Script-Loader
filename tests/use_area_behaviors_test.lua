-- Run from the repository root: lua bundles/illarion-script-loader/tests/use_area_behaviors_test.lua
package.loaded['selene.registries'] = {}
package.loaded['illarion-script-loader.server.lua.lib.inventoryManager'] = {}
local Behaviors = dofile('bundles/moonlight/moonlight-behaviors/server/lua/behaviors.lua')
package.loaded['moonlight-behaviors.server.lua.behaviors'] = Behaviors
local defaults = dofile('bundles/illarion-script-loader/server/lua/lib/behaviorDefaults.lua')
local behaviors = defaults.registerBehaviorDefaults(Behaviors:new())
local calls = 0
behaviors:registerAction('record', function() calls=calls+1 end)
local condition = {type='is_at',data={subject='item',position={x=-72,y=-69,z=0}}}
local definition = {event='use_item',conditions={condition},actions={{type='record'}}}
local item = {pos={x=-72,y=-69,z=0}}
local context = {item=item,character={pos={x=1,y=2,z=0}}}
local function check(expected)
    calls=0
    behaviors:emit('use_item',{definition},context)
    assert(calls==expected)
end
check(1)
item.pos.z=1; check(0)
item.pos={x=-71,y=-69,z=0}; check(0)
context.item=nil; check(0)
condition.data.subject=nil
condition.data.position={x=1,y=2,z=0}; check(1)
condition.data.subject='targetItem'
context.targetItem={pos={x=1,y=2,z=0}}; check(1)
local handlers, emitted, scripts = {}, {}, 0
local event = {connect=function(self,fn) self.listener=fn end,fire=function(self,value)
    emitted[#emitted+1]=value
    self.listener(value)
end}
package.loaded['illarion-script-loader.server.lua.lib.events']={onUseItem=event}
package.loaded['base.areas']={emit=function(name,value)
    assert(name=='use_item')
    assert(value.character==context.character)
end}
package.loaded['npc.runtime']={start=function() end}
dofile('bundles/illarion-gobaith/server/lua/init.lua')
package.loaded['selene.network']={handlePayload=function(name,fn) handlers[name]=fn end}
local legacy=false
package.loaded['selene.config']={getProperty=function() return legacy and 'true' or 'false' end}
package.loaded['illarion-script-loader.server.lua.lib.datakeys']={LastAction='last'}
package.loaded['illarion-script-loader.server.lua.lib.dataFields']={LastActionScript='script',LastActionFunction='fn',LastActionArgs='args'}
package.loaded['illarion-script-loader.server.lua.lib.payloadValidation']={
    string=function(value) return value end,integer=function(value) return value end,
}
local inventoryItem={getItem=function() return {def={getField=function() return 'test.use' end}} end}
package.loaded['illarion-script-loader.server.lua.lib.inventoryManager']={GetInventoryAtView=function()
    return {getInventoryItem=function() return inventoryItem end}
end}
Item={fromSeleneInventoryItem=function() return item end,fromSeleneEmpty=function() return {id=0} end}
Character={fromSelenePlayer=function() return context.character end}
context.character.abortAction=function() end
context.character.SeleneEntity={getRuntimeData=function() return {} end}
Action={none=0}
package.loaded['test.use']={UseItem=function(user,source,target)
    assert(user==context.character and source==item)
    assert(#emitted==scripts+1, 'Area event must fire before the script changes the source item')
    if legacy then assert(target.id==0) else assert(target==Action.none) end
    scripts=scripts+1
end}
dofile('bundles/illarion-script-loader/server/lua/use.lua')
for _, mode in ipairs({false,true}) do
    legacy=mode
    handlers['illarion:use_slot']({}, {viewId='inventory',slotId=0,count=1})
    local value=emitted[#emitted]
    assert(value.item==item and value.counter==1 and value.targetItem.id==0)
end
assert(scripts==2 and #emitted==2)
local schema=defaults.schema().conditions.valueType.properties.data.variants.is_at.properties
assert(schema.position=='coordinate' and schema.subject.type=='enum')
print('use area behavior tests passed')
