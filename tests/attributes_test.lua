package.path = "bundles/moonlight/?.lua;bundles/?.lua;" .. package.path
package.loaded["selene.logging"] = { error = error }
package.loaded["selene.config"] = { getProperty = function() return "false" end }
package.loaded["selene.players"] = {}
local messages = {}
package.loaded["selene.network"] = { sendToEntity = function(entity, message, payload)
    messages[#messages + 1] = { entity = entity, message = message, payload = payload }
end }
local deaths = {}
package.loaded["illarion-script-loader.server.lua.lib.characterManager"] = {
    SetDead = function(_, dead) deaths[#deaths + 1] = dead end,
}
package.loaded["selene.registries"] = { findByMetadata = function()
    return {
        getField = function() return "skill_group_2" end,
        getMetadata = function() return "skill" end,
    }
end }

local runtime = {}
local movementUpdates = 0
local function entityWrapper()
    return {
        getRuntimeData = function(_, key)
            runtime[key] = runtime[key] or {}
            return runtime[key]
        end,
        hasRuntimeData = function(_, key) return runtime[key] ~= nil end,
        updateVisuals = function() end,
        setMovementDurationMultiplier = function(_, value)
            movementUpdates = movementUpdates + 1
            runtime.multiplier = value
        end,
    }
end
local user = { SeleneEntity = entityWrapper() }
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")
local health = AttributeManager.GetAttribute(user, "hitpoints")
assert(AttributeManager.GetAttribute({ SeleneEntity = entityWrapper() }, "hitpoints") == health)
health:setValue(9000)
local offset = AttributeManager.GetAttribute(user, "hitpointsOffset")
offset:setValue(2000)
health:refresh()
assert(offset:getValue() == 1000 and health:getEffectiveValue() == 10000)
local count = #messages
offset:setValue(2000)
assert(#messages == count)
health:setValue(9500)
assert(offset:getValue() == 500 and health:getEffectiveValue() == 10000)
offset:setValue(-20000)
health:refresh()
assert(health:getEffectiveValue() == 0 and deaths[#deaths] == true)
assert(messages[#messages].payload.value == 0)

-- Offset-first initialization must still install bounds and modifiers.
local manaOffset = AttributeManager.GetAttribute(user, "manaOffset")
local mana = AttributeManager.GetAttribute(user, "mana")
mana:setValue(100)
manaOffset:setValue(-200)
assert(manaOffset:getValue() == -100 and mana:getEffectiveValue() == 0)
local strength = AttributeManager.GetAttribute(user, "strength")
strength:setValue(10)
AttributeManager.GetAttribute(user, "strengthOffset"):setValue(2)
assert(strength:getEffectiveValue() == 12)

local SkillManager = require("illarion-script-loader.server.lua.lib.skillManager")
local major = SkillManager.GetMajorSkillAttribute(user, 1)
major:setValue(200)
assert(major:getValue() == 100)
assert(messages[#messages].message == "illarion:skill" and messages[#messages].payload.major == 100)
assert(SkillManager.GetMajorSkillAttribute({ SeleneEntity = entityWrapper() }, 1) == major)
local minor = SkillManager.GetMinorSkillAttribute(user, 1)
minor:setValue(20000)
assert(minor:getValue() == 10000 and messages[#messages].payload.minor == 10000)

local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local Movement = require("illarion-script-loader.server.lua.lib.characterMovement")
user.increaseAttrib = function(_, name)
    return AttributeManager.GetAttribute(user, name):getEffectiveValue()
end
setmetatable(user, { __index = function(_, key)
    if key == "speed" then return AttributeManager.GetAttribute(user, "speed"):getEffectiveValue() end
end })
local speed = AttributeManager.GetAttribute(user, "speed")
speed:setValue(1)
Movement.Configure(user)
local unloaded = runtime.multiplier
local itemDef = { getField = function(_, field)
    if field == "weight" then return 1000 end
    if field == "containerSlots" then return 2 end
end }
local item = { def = itemDef, count = 1 }
InventoryManager.GetEquipment(user):setItem(0, item)
local contents = InventoryManager.GetContentsContainer({ SeleneItem = item })
contents:setItem(1, { def = itemDef, count = 2 })
assert(runtime.multiplier > unloaded)
local loaded = runtime.multiplier
speed:setValue(2)
assert(runtime.multiplier == loaded / 2)
speed:setValue(1)
contents:decreaseCountAt(1, 1)
assert(runtime.multiplier < loaded)

-- Stat offsets and modifier changes publish without a movement request.
local beforeStat = runtime.multiplier
AttributeManager.GetAttribute(user, "agility"):setValue(20)
assert(runtime.multiplier < beforeStat)
beforeStat = runtime.multiplier
AttributeManager.GetAttribute(user, "agilityOffset"):setValue(-10)
assert(runtime.multiplier > beforeStat)
beforeStat = runtime.multiplier
AttributeManager.GetAttribute(user, "strengthOffset"):setValue(100)
assert(runtime.multiplier < beforeStat)
local Attributes = require("moonlight-attributes.server.lua.attributes")
beforeStat = runtime.multiplier
local boost = speed:addModifier("boost", Attributes.mathOpFilter(2, "*"))
assert(runtime.multiplier == beforeStat / 2)
boost.enabled = false
speed:refresh()
assert(runtime.multiplier == beforeStat)
boost.enabled = true
speed:refresh()
speed:removeModifier("boost")
assert(runtime.multiplier == beforeStat)

-- Empty nested containers are subscribed immediately, and detached ones are released.
local nestedItem = { def = itemDef, count = 1 }
contents:setItem(2, nestedItem)
local nested = nestedItem.content
assert(nested ~= nil and #nested._observers == 1)
local emptyWeight = runtime.multiplier
nested:setItem(1, { def = itemDef, count = 5 })
assert(runtime.multiplier > emptyWeight)
contents:setItem(2, nil)
assert(#nested._observers == 0)
local changes = movementUpdates
nested:increaseCountAt(1, 1)
assert(movementUpdates == changes)
contents:setItem(2, nestedItem)
assert(#nested._observers == 1)

-- Reconfiguring does not duplicate subscriptions; item replacement changes weight.
Movement.Configure(user)
assert(#nested._observers == 1 and #speed._observers == 1)
changes = movementUpdates
speed:setValue(2)
assert(movementUpdates == changes + 1)
local beforeReplacement = runtime.multiplier
nested:getItem(1).def = { getField = function(_, field)
    if field == "weight" then return 10 end
end }
nested:slotUpdated(1)
assert(runtime.multiplier < beforeReplacement)

InventoryManager.GetEquipment(user):setItem(0, nil)
assert(#contents._observers == 0 and #nested._observers == 0)
changes = movementUpdates
contents:setItem(1, nil)
assert(movementUpdates == changes)

-- Only carried inventories contribute; depot changes have no movement listeners.
local depot = InventoryManager.GetDepot(user, 1)
depot:setItem(1, { def = itemDef, count = 100 })
assert(movementUpdates == changes and #depot._observers == 0)
print("Attribute integration tests passed")
