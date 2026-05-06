local Attributes = require("selene.attributes")
local Network = require("selene.network")

local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")

local m = {}

function m.GetAttribute(user, attributeName)
    local attributeKey = "illarion:" .. attributeName
    local attribute = user.SeleneEntity:getAttribute(attributeKey)
    if attribute == nil then
        local initialValue = 0
        if attributeName == "skinColor" or attributeName == "hairColor" then
            initialValue = colour(255, 255, 255)
        end
        attribute = user.SeleneEntity:createAttribute(attributeKey, initialValue)
        if attributeName == "hitpoints" then
            local max = 10000
            attribute:addModifier("offset", Attributes.mathOpFilter(m.GetAttribute(user, "hitpointsOffset"), "+"))
            attribute:addModifier("clamp", Attributes.clampFilter(0, max))
            attribute:addConstraint("clamp", Attributes.clampFilter(0, max))
            attribute:subscribe(function(attribute)
                CharacterManager.SetDead(user, attribute:getEffectiveValue() <= 0)
                Network.sendToEntity(attribute:getOwner(), "illarion:health", { value = attribute:getEffectiveValue() / max })
            end)
        elseif attributeName == "foodlevel" then
            local max = 60000
            attribute:addModifier("offset", Attributes.mathOpFilter(m.GetAttribute(user, "foodlevelOffset"), "+"))
            attribute:addModifier("clamp", Attributes.clampFilter(0, max))
            attribute:addConstraint("clamp", Attributes.clampFilter(0, max))
            attribute:subscribe(function(attribute)
                Network.sendToEntity(attribute:getOwner(), "illarion:food", { value = attribute:getEffectiveValue() / max })
            end)
        elseif attributeName == "mana" then
            local max = 10000
            attribute:addModifier("offset", Attributes.mathOpFilter(m.GetAttribute(user, "manaOffset"), "+"))
            attribute:addModifier("clamp", Attributes.clampFilter(0, max))
            attribute:addConstraint("clamp", Attributes.clampFilter(0, max))
            attribute:subscribe(function(attribute)
                Network.sendToEntity(attribute:getOwner(), "illarion:mana", { value = attribute:getEffectiveValue() / max })
            end)
        elseif attributeName == "strength" or attributeName == "dexterity" or attributeName == "constitution" or attributeName == "agility" or attributeName == "intelligence" or attributeName == "essence" or attributeName == "perception" or attributeName == "willpower" then
            attribute:addModifier("offset", Attributes.mathOpFilter(m.GetAttribute(user, attributeName .. "Offset"), "+"))
            attribute:addModifier("clamp", Attributes.clampFilter(0, 255))
            attribute:addConstraint("clamp", Attributes.clampFilter(0, 255))
        elseif attributeName == "actionpoints" then
            attribute:addConstraint("clamp", Attributes.clampFilter(0, 21))
        elseif attributeName == "fightpoints" then
            attribute:addConstraint("clamp", Attributes.clampFilter(0, 0))
        end
    end
    return attribute
end

return m