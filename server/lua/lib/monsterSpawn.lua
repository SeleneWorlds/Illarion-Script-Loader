local Registries = require("selene.registries")
local Schedules = require("selene.schedules")
local Dimensions = require("selene.dimensions")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local MonsterSpawn = {}

MonsterSpawn.ByName = {}

function MonsterSpawn:new(o)
    o = o or {}
    if not o.def then
        error("Missing def field in MonsterSpawn")
    end
    o.monsterTypes = {}
    local monsters = o.def:getField("monsters")
    if monsters then
        for monsterName, monsterCount in pairs(monsters) do
            table.insert(o.monsterTypes, {name = monsterName, count = 0, maxCount = monsterCount})
        end
    end
    setmetatable(o, self)
    self.__index = self
    MonsterSpawn.ByName[o.def:getName()] = o
    return o
end

function MonsterSpawn.Remove(identifier)
    local spawn = MonsterSpawn.ByName[identifier]
    if spawn then
        spawn.stopped = true
        if spawn.timeoutId then
            Schedules.clearTimeout(spawn.timeoutId)
            spawn.timeoutId = nil
        end
        MonsterSpawn.ByName[identifier] = nil
    end
    local MonsterManager = require("illarion-script-loader.server.lua.lib.monsterManager")
    MonsterManager.RemoveBySpawn(identifier)
end

function MonsterSpawn.RemoveAll()
    local identifiers = {}
    for identifier in pairs(MonsterSpawn.ByName) do
        identifiers[#identifiers + 1] = identifier
    end
    for _, identifier in ipairs(identifiers) do
        MonsterSpawn.Remove(identifier)
    end
end

function MonsterSpawn:scheduleNext()
    if self.stopped then return end
    local minSpawnTime = self.def:getField("minSpawnTime")
    local maxSpawnTime = self.def:getField("maxSpawnTime")
    local interval = math.random(minSpawnTime, maxSpawnTime)
    self.timeoutId = Schedules.setTimeout(interval * 1000, function()
        self.timeoutId = nil
        self:spawn()
    end)
end

function MonsterSpawn:monsterRemoved(monsterDef)
    for _, monsterType in ipairs(self.monsterTypes) do
        if monsterType.name == monsterDef:getName() then
            monsterType.count = math.max(0, monsterType.count - 1)
            return
        end
    end
end

function MonsterSpawn:spawn()
    if self.stopped then return end
    -- TODO check if spawn is enabled
    local dimension = Dimensions.getDefault()
    for _, monsterType in ipairs(self.monsterTypes) do
        local num = monsterType.maxCount - monsterType.count
        local monsterDef = Registries.findByName("illarion:monsters", monsterType.name)
        if monsterDef and num > 0 then
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
                local pos = position(x, y, z)
                if not dimension:hasCollisionAt(pos) then
                    local monster = world:createMonster(monsterDef:getMetadata("id"), pos, 0)
                    local charData = monster.SeleneEntity:getRuntimeData(DataKeys.Character)
                    charData[DataFields.MonsterSpawn] = self.def:getName()
                    monsterType.count = monsterType.count + 1
                end
            end
        end
    end
    self:scheduleNext()
end

return MonsterSpawn
