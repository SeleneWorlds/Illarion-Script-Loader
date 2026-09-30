local Registries = require("selene.registries")
local Entities = require("selene.entities")
local Grid = require("selene.grid")

local Constants = require("illarion-script-loader.server.lua.lib.constants")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local RouteManager = require("illarion-script-loader.server.lua.lib.routeManager")

local m = {}

local ACTIVE_RANGE = 60
local RANDOM_MOVE_INTERVAL_TICKS = 20

local DIRECTIONS = {
    [Character.north] = {x = 0, y = -1},
    [Character.northeast] = {x = 1, y = -1},
    [Character.east] = {x = 1, y = 0},
    [Character.southeast] = {x = 1, y = 1},
    [Character.south] = {x = 0, y = 1},
    [Character.southwest] = {x = -1, y = 1},
    [Character.west] = {x = -1, y = 0},
    [Character.northwest] = {x = -1, y = -1}
}

m.IdCounter = 0
m.EntitiesById = {}
m.NewMonsters = {}
m.UpdateTick = 0

local function getRandomDirection()
    local directions = {}
    for direction in pairs(DIRECTIONS) do
        local name = DirectionUtils.IllaToSelene(direction)
        local supported = name and pcall(Grid.getDirectionByName, name)
        if supported then
            directions[#directions + 1] = direction
        end
    end

    if #directions == 0 then
        return nil
    end
    return directions[math.random(#directions)]
end

local function keepDirectionInsideSpawn(monster, direction, spawn)
    if not spawn then
        return direction
    end

    local spawnRange = spawn.def:getField("range")
    if spawnRange == nil then
        return direction
    end

    local offset = DIRECTIONS[direction]
    local x = monster.pos.x + offset.x
    local y = monster.pos.y + offset.y
    local centerX = spawn.def:getField("x")
    local centerY = spawn.def:getField("y")

    if math.abs(centerX - x) > spawnRange then
        offset = {x = -offset.x, y = offset.y}
    end
    if math.abs(centerY - y) > spawnRange then
        offset = {x = offset.x, y = -offset.y}
    end

    for candidate, candidateOffset in pairs(DIRECTIONS) do
        if candidateOffset.x == offset.x and candidateOffset.y == offset.y then
            return candidate
        end
    end
    return direction
end

local function makeRandomMove(monster, charData)
    if #world:getPlayersInRangeOf(monster.pos, ACTIVE_RANGE) == 0 then
        return
    end

    local spawn
    local spawnName = charData[DataFields.MonsterSpawn]
    if spawnName then
        local MonsterSpawn = require("illarion-script-loader.server.lua.lib.monsterSpawn")
        spawn = MonsterSpawn.ByName[spawnName]
    end

    local direction = getRandomDirection()
    if direction == nil then
        return
    end
    direction = keepDirectionInsideSpawn(monster, direction, spawn)
    monster:move(direction)
end

function m.Spawn(monsterDef, pos)
    local raceName = monsterDef:getField("race")
    local race = Registries.findByName("illarion:races", raceName)
    if not race then
        error("Unknown monster race " .. raceName)
    end

    local entity = Entities.create(race:getIdentifier():withPrefix("races/"):withSuffix("_0"))
    m.IdCounter = m.IdCounter + 1
    local charData = entity:getRuntimeData(DataKeys.Character)
    charData[DataFields.ID] = (m.IdCounter + Constants.MONSTER_BASE_ID) % (Constants.NPC_BASE_ID - Constants.MONSTER_BASE_ID)
    charData[DataFields.CharacterType] = Character.monster
    charData[DataFields.Race] = race:getMetadata("id")
    charData[DataFields.Monster] = monsterDef
    charData[DataFields.Script] = monsterDef:getField("script")
    entity:setCoordinate(pos)
    table.insert(m.NewMonsters, entity)
    return Character.fromSeleneEntity(entity)
end

function m.Remove(entity)
    local charData = entity:getRuntimeData(DataKeys.Character)
    local id = charData[DataFields.ID]
    local spawnName = charData[DataFields.MonsterSpawn]

    m.EntitiesById[id] = nil
    CharacterManager.RemoveEntity(entity)

    if spawnName then
        local MonsterSpawn = require("illarion-script-loader.server.lua.lib.monsterSpawn")
        local spawn = MonsterSpawn.ByName[spawnName]
        local monsterDef = charData[DataFields.Monster]
        if spawn and monsterDef then
            spawn:monsterRemoved(monsterDef)
        end
    end

    entity:remove()
end

function m.Update()
    m.UpdateTick = m.UpdateTick + 1

    for _, entity in pairs(m.NewMonsters) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        charData[DataFields.NextRandomMoveTick] = m.UpdateTick + math.random(1, RANDOM_MOVE_INTERVAL_TICKS)
        m.EntitiesById[charData[DataFields.ID]] = entity
        CharacterManager.AddEntity(entity)
        entity:spawn()

        local status, script = pcall(require, charData[DataFields.Script])
        if status and type(script.onSpawn) == "function" then
            script.onSpawn(Character.fromSeleneEntity(entity))
        end
    end
    m.NewMonsters = {}

    for _, entity in pairs(m.EntitiesById) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if not charData[DataFields.Dead] then
            local monster = Character.fromSeleneEntity(entity)
            local routeStatus = RouteManager.Advance(monster)
            if routeStatus == "complete" or routeStatus == "blocked" then
                monster:setOnRoute(false)
                local status, script = pcall(require, charData[DataFields.Script])
                if status and type(script.abortRoute) == "function" then
                    script.abortRoute(monster)
                end
            end
            local nextRandomMoveTick = charData[DataFields.NextRandomMoveTick] or m.UpdateTick
            if routeStatus == "idle" and m.UpdateTick >= nextRandomMoveTick then
                makeRandomMove(monster, charData)
                charData[DataFields.NextRandomMoveTick] = m.UpdateTick + RANDOM_MOVE_INTERVAL_TICKS
            end
        end
    end
end

return m
