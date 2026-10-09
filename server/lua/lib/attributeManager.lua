local Attributes = require("selene.attributes")
local Network = require("selene.network")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local m = {}

local function updateActionPointControls(attribute)
    local points = attribute:getEffectiveValue()
    local owner = attribute:getOwner()
    local frozen = owner:getRuntimeData(DataKeys.Character)[DataFields.Frozen]
    for _, player in ipairs(owner:getControllingPlayers()) do
        -- Illarion requires 7 action points to move and 1 to turn.
        player:setCanMove(not frozen and points >= 7)
        player:setCanTurn(points >= 1)
    end
end

local resourceAttributes = {
    hitpoints = { max = 10000, message = "illarion:health" },
    mana = { max = 10000, message = "illarion:mana" },
    foodlevel = { max = 60000, message = "illarion:food" },
}
local resourceOffsets = {
    hitpointsOffset = "hitpoints",
    manaOffset = "mana",
    foodlevelOffset = "foodlevel",
}

function m.GetAttribute(user, attributeName)
    local attributeKey = "illarion:" .. attributeName
    local attribute = user.SeleneEntity:getAttribute(attributeKey)
    if attribute == nil then
        local initialValue = 0
        if attributeName == "skinColor" or attributeName == "hairColor" then
            initialValue = colour(255, 255, 255)
        elseif attributeName == "actionpoints" then
            initialValue = 21
        end
        attribute = user.SeleneEntity:createAttribute(attributeKey, initialValue)
        local resource = resourceAttributes[attributeName]
        if resource then
            local max = resource.max
            local baseAttribute = attribute
            local offset = m.GetAttribute(user, attributeName .. "Offset")
            local function clampOffset(value)
                local base = baseAttribute:getValue()
                return math.max(-base, math.min(max - base, value))
            end
            offset:addConstraint("resourceBounds", function(_, value)
                return clampOffset(value)
            end)
            attribute:addModifier("offset", Attributes.mathOpFilter(offset, "+"))
            attribute:addModifier("clamp", Attributes.clampFilter(0, max))
            attribute:addConstraint("clamp", Attributes.clampFilter(0, max))
            attribute:subscribe(function(attribute)
                -- Base values can change independently of their offsets.
                -- Clamp the stored total before publishing the resource value.
                offset:setValue(clampOffset(offset:getValue()))
                if attributeName == "hitpoints" then
                    require("illarion-script-loader.server.lua.lib.characterManager").SetDead(user, attribute:getEffectiveValue() <= 0)
                end
                Network.sendToEntity(attribute:getOwner(), resource.message, { value = attribute:getEffectiveValue() / max })
            end)
        elseif resourceOffsets[attributeName] then
            -- Explicitly install bounds even when an offset is requested first.
            m.GetAttribute(user, resourceOffsets[attributeName])
        elseif attributeName == "strength" or attributeName == "dexterity" or attributeName == "constitution" or attributeName == "agility" or attributeName == "intelligence" or attributeName == "essence" or attributeName == "perception" or attributeName == "willpower" then
            attribute:addModifier("offset", Attributes.mathOpFilter(m.GetAttribute(user, attributeName .. "Offset"), "+"))
            attribute:addModifier("clamp", Attributes.clampFilter(0, 255))
            attribute:addConstraint("clamp", Attributes.clampFilter(0, 255))
        elseif attributeName == "actionpoints" then
            attribute:addConstraint("clamp", Attributes.clampFilter(math.mininteger, 21))
            attribute:subscribe(updateActionPointControls)
            updateActionPointControls(attribute)
        elseif attributeName == "body_height" then
            attribute:subscribe(function(attribute)
                attribute:getOwner():updateVisuals()
            end)
        elseif attributeName == "fightpoints" then
            attribute:addConstraint("clamp", Attributes.clampFilter(math.mininteger, 21))
        end
    end
    return attribute
end

return m
