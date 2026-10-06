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

local EQUIPMENT_SLOTS = {
    backpack = Character.backpack,
    head = Character.head,
    neck = Character.neck,
    breast = Character.breast,
    hands = Character.hands,
    ["left hand"] = Character.left_tool,
    ["right hand"] = Character.right_tool,
    ["left finger"] = Character.finger_left_hand,
    ["right finger"] = Character.finger_right_hand,
    legs = Character.legs,
    feet = Character.feet,
    coat = Character.coat
}

m.IdCounter = 0
m.NewMonsters = {}
m.UpdateTick = 0

local function getRandomDirection()
    local directions = {}
    for direction in pairs(DIRECTIONS) do
        local name = DirectionUtils.IllaToSelene(direction)
        local supported = name and xpcall(Grid.getDirectionByName, name)
        if supported then
            directions[#directions + 1] = direction
        end
    end

    if #directions == 0 then
        return nil
    end
    return directions[math.random(#directions)]
end

local function randomDefinitionValue(range)
    local minimum = tonumber(range.min) or 0
    local maximum = tonumber(range.max) or minimum
    return math.random(math.min(minimum, maximum), math.max(minimum, maximum))
end

local function initializeAttributes(monster, monsterDef)
    local attributes = monsterDef:getField("attributes")
    if attributes then
        for name, range in pairs(attributes) do
            monster:setAttrib(name, randomDefinitionValue(range))
        end
    end

    monster:setAttrib("hitpoints", tonumber(monsterDef:getField("hitpoints")) or 0)

    local minSize = tonumber(monsterDef:getField("minSize"))
    local maxSize = tonumber(monsterDef:getField("maxSize")) or minSize
    if minSize then
        monster:setAttrib(
            "body_height",
            math.random(math.min(minSize, maxSize), math.max(minSize, maxSize))
        )
    end
end

local function initializeSkills(monster, monsterDef)
    local skills = monsterDef:getField("skills")
    if not skills then
        return
    end
    for skillName, range in pairs(skills) do
        local skillDef = Registries.findByName("illarion:skills", skillName)
        local skillId = skillDef and tonumber(skillDef:getMetadata("id"))
        if skillId then
            monster:setSkill(skillId, randomDefinitionValue(range), 0)
        end
    end
end

local function initializeItems(monster, monsterDef)
    local items = monsterDef:getField("items")
    if not items then
        return
    end
    for slotName, itemData in pairs(items) do
        local slotId = EQUIPMENT_SLOTS[slotName]
        local itemDef = Registries.findByName("illarion:items", itemData.item)
        if slotId ~= nil and itemDef then
            local count = randomDefinitionValue({
                min = itemData.minCount or 1,
                max = itemData.maxCount or itemData.minCount or 1
            })
            monster:createAtPos(slotId, tonumber(itemDef:getMetadata("id")), count)
        end
    end
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
    charData[DataFields.ID] = Constants.MONSTER_BASE_ID
        + (m.IdCounter % (Constants.NPC_BASE_ID - Constants.MONSTER_BASE_ID))
    charData[DataFields.CharacterType] = Character.monster
    charData[DataFields.Race] = race:getMetadata("id")
    charData[DataFields.Monster] = monsterDef
    charData[DataFields.Script] = monsterDef:getField("script")
    entity:setCoordinate(pos)
    local monster = Character.fromSeleneEntity(entity)
    initializeAttributes(monster, monsterDef)
    initializeSkills(monster, monsterDef)
    initializeItems(monster, monsterDef)
    table.insert(m.NewMonsters, entity)
    return monster
end

function m.Remove(entity)
    local charData = entity:getRuntimeData(DataKeys.Character)
    local spawnName = charData[DataFields.MonsterSpawn]

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

function m.RemoveAll()
    local entities = {}
    for _, entity in ipairs(Entities.findAllByTag("illarion:character")) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if charData[DataFields.CharacterType] == Character.monster then
            entities[#entities + 1] = entity
        end
    end
    for _, entity in pairs(m.NewMonsters) do
        entities[#entities + 1] = entity
    end
    for _, entity in ipairs(entities) do
        m.Remove(entity)
    end
    m.NewMonsters = {}
end

function m.Update()
    m.UpdateTick = m.UpdateTick + 1

    for _, entity in pairs(m.NewMonsters) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        charData[DataFields.NextRandomMoveTick] = m.UpdateTick + math.random(1, RANDOM_MOVE_INTERVAL_TICKS)
        CharacterManager.AddEntity(entity)
        entity:spawn()

        local status, script = xpcall(require, charData[DataFields.Script])
        if status and type(script.onSpawn) == "function" then
            script.onSpawn(Character.fromSeleneEntity(entity))
        end
    end
    m.NewMonsters = {}

    for _, entity in ipairs(Entities.findAllByTag("illarion:character")) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if charData[DataFields.CharacterType] == Character.monster and not charData[DataFields.Dead] then
            local monster = Character.fromSeleneEntity(entity)
            local routeStatus = RouteManager.Advance(monster)
            if routeStatus == "complete" or routeStatus == "blocked" then
                monster:setOnRoute(false)
                local status, script = xpcall(require, charData[DataFields.Script])
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
