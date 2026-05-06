local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")

Character.SeleneMethods.getSkinColour = function(user)
    return AttributeManager.GetAttribute(user, "skinColor"):getEffectiveValue()
end

Character.SeleneMethods.setSkinColour = function(user, skinColor)
    AttributeManager.GetAttribute(user, "skinColor"):setValue(skinColor)
end

Character.SeleneMethods.getHairColour = function(user)
    return AttributeManager.GetAttribute(user, "hairColor"):getEffectiveValue()
end

Character.SeleneMethods.setHairColour = function(user, hairColor)
    AttributeManager.GetAttribute(user, "hairColor"):setValue(hairColor)
end

Character.SeleneMethods.getHair = function(user)
    return AttributeManager.GetAttribute(user, "hair"):getEffectiveValue()
end

Character.SeleneMethods.setHair = function(user, hairId)
    AttributeManager.GetAttribute(user, "hair"):setValue(hairId)
end

Character.SeleneMethods.getBeard = function(user)
    return AttributeManager.GetAttribute(user, "beard"):getEffectiveValue()
end

Character.SeleneMethods.setBeard = function(user, beardId)
    AttributeManager.GetAttribute(user, "beard"):setValue(beardId)
end