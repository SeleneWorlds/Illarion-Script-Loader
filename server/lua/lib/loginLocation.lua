local Registries = require("selene.registries")
local Areas = require("base.areas")
local M = {}

---Resolve the login subtitle using the character's saved coordinates.
function M.getName(coordinate)
    local matches = {}
    for _, entry in pairs(Registries.findAll("illarion:areas")) do
        if entry:getField("enabled") == true then
            for _, tag in ipairs(entry:getField("tags") or {}) do
                if tag == "login_location" then
                    if Areas.contains(entry:getField("area"), coordinate,
                        { ignoreFloor = entry:getField("ignoreFloor") == true }) then
                        matches[#matches + 1] = entry
                    end
                    break
                end
            end
        end
    end
    -- Keep overlapping areas deterministic, independent of registry iteration order.
    table.sort(matches, function(a, b) return a:getName() < b:getName() end)
    return matches[1] and matches[1]:getField("name") or "Wilderness"
end

return M
