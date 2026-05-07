local Registries = require("selene.registries")
local Schedules = require("selene.schedules")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local MonsterSpawn = {}

MonsterSpawn.ByName = {}

function MonsterSpawn:new(o)
    o = o or {}
    if not o.def then
        error("Missing def field in MonsterSpawn")
    end
    MonsterSpawn.ByName[o.def:getName()] = o
    o.monsterTypes = {}
    local monsters = o.def:getField("monsters")
    if monsters then
        for monsterName, monsterCount in pairs(monsters) do
            local monsterDef = Registries.findByName("illarion:monsters", monsterName)
            if not monsterDef then
                error("Unknown monster " .. monsterName .. " in spawn " .. o.def:getName())
            end
            table.insert(o.monsterTypes, {def = monsterDef, count = 0, maxCount = monsterCount})
        end
    end
    setmetatable(o, self)
    self.__index = self
    return o
end

function MonsterSpawn:scheduleNext()
    local minSpawnTime = self.def:getField("minSpawnTime")
    local maxSpawnTime = self.def:getField("maxSpawnTime")
    local interval = math.random(minSpawnTime, maxSpawnTime)
    Schedules.setTimeout(interval * 1000, function()
        self:spawn()
    end)
end

function MonsterSpawn:spawn()
    -- TODO check if spawn is enabled
    local monsters = self.def:getField("monsters")
    for _, monsterType in ipairs(self.monsterTypes) do
        local num = monsterType.maxCount - monsterType.count
        if num > 0 then
            if not self.def:getField("spawnAll") then
                num = math.random(1, num)
            end
            local centerX = self.def:getField("x")
            local centerY = self.def:getField("y")
            local z = self.def:getField("z")
            local spawnRange = self.def:getField("spawnRange")
            for i = 1, num do
                local x = centerX + math.random(-spawnRange, spawnRange)
                local y = centerY + math.random(-spawnRange, spawnRange)
                -- TODO find nearby passable location
                local pos = position(x, y, z)
                local monster = world:createMonster(monsterType.def:getMetadata("id"), pos, 0)
                local charData = monster.SeleneEntity:getRuntimeData(DataKeys.Character)
                charData[DataFields.MonsterSpawn] = self.def:getName()
                monsterType.count = monsterType.count + 1
            end
        end
    end
    self:scheduleNext()
end

return MonsterSpawn