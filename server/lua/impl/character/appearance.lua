local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")

Character.SeleneMethods.getSkinColour = function(user)
    return AttributeManager.GetAttribute(user, "skinColor"):getEffectiveValue()
end

Character.SeleneMethods.setSkinColour = function(user, skinColor)
    assert(type(skinColor) == "table", "skinColor must be a colour, was " .. tostring(skinColor))
    skinColor.red = assert(tonumber(skinColor.red), "skinColor.red must be a number, was " .. tostring(skinColor.red))
    skinColor.green = assert(tonumber(skinColor.green), "skinColor.green must be a number, was " .. tostring(skinColor.green))
    skinColor.blue = assert(tonumber(skinColor.blue), "skinColor.blue must be a number, was " .. tostring(skinColor.blue))
    skinColor.alpha = skinColor.alpha == nil and 255 or assert(tonumber(skinColor.alpha), "skinColor.alpha must be a number, was " .. tostring(skinColor.alpha))
    AttributeManager.GetAttribute(user, "skinColor"):setValue(skinColor)
end

Character.SeleneMethods.getHairColour = function(user)
    return AttributeManager.GetAttribute(user, "hairColor"):getEffectiveValue()
end

Character.SeleneMethods.setHairColour = function(user, hairColor)
    assert(type(hairColor) == "table", "hairColor must be a colour, was " .. tostring(hairColor))
    hairColor.red = assert(tonumber(hairColor.red), "hairColor.red must be a number, was " .. tostring(hairColor.red))
    hairColor.green = assert(tonumber(hairColor.green), "hairColor.green must be a number, was " .. tostring(hairColor.green))
    hairColor.blue = assert(tonumber(hairColor.blue), "hairColor.blue must be a number, was " .. tostring(hairColor.blue))
    hairColor.alpha = hairColor.alpha == nil and 255 or assert(tonumber(hairColor.alpha), "hairColor.alpha must be a number, was " .. tostring(hairColor.alpha))
    AttributeManager.GetAttribute(user, "hairColor"):setValue(hairColor)
end

Character.SeleneMethods.getHair = function(user)
    return AttributeManager.GetAttribute(user, "hair"):getEffectiveValue()
end

Character.SeleneMethods.setHair = function(user, hairId)
    hairId = assert(tonumber(hairId), "hairId must be a number, was " .. tostring(hairId))
    AttributeManager.GetAttribute(user, "hair"):setValue(hairId)
end

Character.SeleneMethods.getBeard = function(user)
    return AttributeManager.GetAttribute(user, "beard"):getEffectiveValue()
end

Character.SeleneMethods.setBeard = function(user, beardId)
    beardId = assert(tonumber(beardId), "beardId must be a number, was " .. tostring(beardId))
    AttributeManager.GetAttribute(user, "beard"):setValue(beardId)
end
