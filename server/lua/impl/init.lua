local Registries = require("selene.registries")
local Bit32 = require("bit32")

LuaAnd = Bit32.band
LuaOr = Bit32.bor
LuaLShift32 = Bit32.lshift
LuaRShift32 = Bit32.rshift

local allRaces = Registries.findAll("illarion:races")
for _, race in pairs(allRaces) do
    local raceName = race:getMetadata("name") or "race_" .. race:getMetadata("id")
    Character[raceName] = race:getMetadata("id")
end

local allSkills = Registries.findAll("illarion:skills")
for _, skill in pairs(allSkills) do
    Character[skill:getMetadata("name")] = skill:getMetadata("id")
end

local allItems = Registries.findAll("illarion:items")
for _, item in pairs(allItems) do
    local name = item:getField("name")
    if name then
        Item[name] = item:getMetadata("id")
    end
end
