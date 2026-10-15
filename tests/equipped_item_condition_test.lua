-- Run from the repository root: lua bundles/illarion-script-loader/tests/equipped_item_condition_test.lua
local function itemDefinition(id)
    return {getMetadata=function(_,key) assert(key=='id'); return id end}
end
package.loaded['selene.registries']={findByName=function(registry,name)
    assert(registry=='illarion:items')
    if name=='illarion:item_52' then return itemDefinition(52) end
end}
local equipped, slot
local user={}
package.loaded['illarion-script-loader.server.lua.lib.inventoryManager']={
    GetEquipment=function(character)
        assert(character==user)
        return {getItem=function(_,value) assert(value==slot); return equipped end}
    end,
    IsBlockedHandItem=function(item) return item.def:getMetadata('id')==228 end,
}
local Behaviors=dofile('bundles/moonlight/moonlight-behaviors/server/lua/behaviors.lua')
package.loaded['moonlight-behaviors.server.lua.behaviors']=Behaviors
local defaults=dofile('bundles/illarion-script-loader/server/lua/lib/behaviorDefaults.lua')
local runner=defaults.registerBehaviorDefaults(Behaviors:new())
local calls=0
runner:registerAction('record',function() calls=calls+1 end)
local condition={type='has_item_equipped_at',data={slot=0}}
local definition={conditions={condition},actions={{type='record'}}}
local function check(expected)
    calls=0
    runner:run(definition,{character=user})
    assert(calls==(expected and 1 or 0))
end
for _, value in ipairs({0,5,6,11}) do
    slot=value; condition.data.slot=value
    equipped=nil; condition.data.item=nil; check(false)
    equipped={def=itemDefinition(52)}; check(true)
    condition.data.item='illarion:item_52'; check(true)
    equipped={def=itemDefinition(51)}; check(false)
    condition.data.item=nil; check(true)
    equipped={def=itemDefinition(228)}; check(false)
    condition.data.item='illarion:item_52'; check(false)
end
for _, invalid in ipairs({-1,12,1.5,'5',false}) do
    condition.data={slot=invalid}
    assert(not pcall(runner.run,runner,definition,{character=user}))
end
for _, invalid in ipairs({42,false,'illarion:missing'}) do
    condition.data={slot=5,item=invalid}
    assert(not pcall(runner.run,runner,definition,{character=user}))
end
slot=5
condition.data={slot=5,item='illarion:item_52',data=42}
equipped={def=itemDefinition(52),data={data='42'}}; check(true)
condition.data.data=43; check(false)
condition.data.item=nil; condition.data.data=42; check(true)
equipped.def=itemDefinition(51); check(true)
condition.data.item='illarion:item_52'; check(false)
equipped.def=itemDefinition(52)
condition.data.data=nil; check(true)
condition.data.data=0; equipped.data=nil; check(true)
equipped.data={}; check(true)
equipped.data={data='0'}; check(true)
equipped.data={data=42}; check(false)
condition.data.data=42; check(true)
equipped=nil; check(false)
equipped={def=itemDefinition(228),data={data='42'}}; check(false)
for _, invalid in ipairs({'42',false,math.huge,0/0}) do
    condition.data={slot=5,data=invalid}
    assert(not pcall(runner.run,runner,definition,{character=user}))
end
local schema=defaults.schema().conditions.valueType.properties.data.variants.has_item_equipped_at.properties
assert(schema.slot.type=='enum' and #schema.slot.values==12)
for index, option in ipairs(schema.slot.values) do
    assert(option.value==index-1 and type(option.label)=='string')
end
assert(schema.slot.values[6].label=='Left hand' and schema.slot.values[7].label=='Right hand')
assert(defaults.schema().conditions.valueType.properties.data.variants.has_any_item_equipped_at.properties.slot.type=='enum')
assert(schema.item.registry=='illarion:items' and schema.item.optional)
assert(schema.data.type=='number' and schema.data.optional)
print('equipped item condition tests passed')
