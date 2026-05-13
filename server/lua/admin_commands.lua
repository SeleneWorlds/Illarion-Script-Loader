local Config = require("selene.config")
local Players = require("selene.players")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

local m = {}

local LANGUAGE_MAP = {
    common = Player.common,
    human = Player.human,
    dwarf = Player.dwarf,
    elf = Player.elf,
    lizard = Player.lizard,
    orc = Player.orc,
    halfling = Player.halfling,
    fairy = Player.fairy,
    gnome = Player.gnome,
    goblin = Player.goblin,
    ancient = Player.ancient,
}

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function splitWords(text)
    local result = {}
    for word in text:gmatch("%S+") do
        table.insert(result, word)
    end
    return result
end

local function findCharacterByName(name)
    local normalizedName = trim(name):lower()
    if normalizedName == "" then
        return nil
    end

    for _, player in ipairs(Players.getOnlinePlayers()) do
        local entity = player:getControlledEntity()
        if entity then
            local character = Character.fromSelenePlayer(player)
            if entity:getName():lower() == normalizedName or tostring(character.id) == normalizedName then
                return character
            end
        end
    end

    return nil
end

local function requireAdmin(character, commandLine)
    if not character:isAdmin() then
        character:inform("Nur Administratoren koennen diesen Befehl benutzen.", "Only administrators can use this command.")
        return false
    end

    character:logAdmin(commandLine)
    return true
end

local function informUnknown(character, command)
    character:inform("Unbekannter Befehl: !" .. command, "Unknown command: !" .. command)
end

local function handleGm(character, args)
    if args == "" then
        character:inform("Benutzung: !gm <Nachricht>", "Usage: !gm <message>")
        return
    end

    character:pageGM(args)
    character:inform(
        "--- Die Nachricht wurde an das GM-Team gesendet. ---",
        "--- The message has been delivered to the GM team. ---"
    )
end

local function handleLanguage(character, args)
    local languageName = trim(args):lower()
    local language = LANGUAGE_MAP[languageName] or languageName
    if language == nil then
        character:inform("Unbekannte Sprache.", "Unknown language.")
        return
    end

    character.activeLanguage = language
    character:inform("Sprache gesetzt: " .. languageName, "Language set: " .. languageName)
end

local function handleVersion(character)
    local version = Config.getProperty("serverVersion") or Config.getProperty("version") or "Selene"
    character:inform("Version: " .. version)
end

local function handleWho(character, args)
    local targetName = trim(args)
    if targetName == "" then
        local names = {}
        for _, player in ipairs(world:getPlayersOnline()) do
            table.insert(names, player.name)
        end
        if #names == 0 then
            character:inform("Keine Spieler online.", "No players online.")
        else
            character:inform(table.concat(names, ", "))
        end
        return
    end

    local target = findCharacterByName(targetName)
    if not target then
        character:inform("*** Konnte " .. targetName .. " nicht finden.", "*** Could not find " .. targetName .. ".")
        return
    end

    local hp = target:increaseAttrib("hitpoints", 0)
    local alive = hp > 0 and "Alive" or "Dead"
    local language = target:getPlayerLanguage() == Player.german and "German" or "English"
    character:inform(string.format(
        "%s x%d y%d z%d HPs:%d %s %s",
        target.name,
        target.pos.x,
        target.pos.y,
        target.pos.z,
        hp,
        alive,
        language
    ))
end

local function handleForceIntroduce(character, args)
    local target = findCharacterByName(args)
    if not target then
        character:inform("*** Spieler nicht gefunden.", "*** Player not found.")
        return
    end

    character:introduce(target)
    character:inform("Einfuehrung abgeschlossen.", "Introduction completed.")
end

local function handleForceIntroduceAll(character)
    local introduced = 0
    for _, target in ipairs(world:getPlayersInRangeOf(character.pos, 20)) do
        if target.id ~= character.id then
            character:introduce(target)
            introduced = introduced + 1
        end
    end
    character:inform("Eingefuehrte Spieler: " .. introduced, "Introduced players: " .. introduced)
end

local function handleTalkTo(character, args)
    local playerName, message = args:match("^(.-)%s*,%s*(.+)$")
    if not playerName or not message then
        character:inform("Benutzung: !talkto <Spieler>, <Nachricht>", "Usage: !talkto <player>, <message>")
        return
    end

    local target = findCharacterByName(playerName)
    if not target then
        character:inform("*** Spieler nicht gefunden.", "*** Player not found.")
        return
    end

    target:inform(message)
    character:inform("to " .. target.name .. ": " .. message)
end

local function handleBroadcast(character, args)
    local message = trim(args)
    if message == "" then
        character:inform("Benutzung: !broadcast <Nachricht>", "Usage: !broadcast <message>")
        return
    end

    world:broadcast(message, message)
end

local function handleCreate(character, args)
    local words = splitWords(args)
    if #words == 0 then
        character:inform("Benutzung: !create <id|name> [quantity [quality [key=value ...]]]", "Usage: !create <id|name> [quantity [quality [key=value ...]]]")
        return
    end

    local itemId = tonumber(words[1]) or Item[words[1]]
    if not itemId then
        character:inform("Unbekanntes Item: " .. words[1], "Unknown item: " .. words[1])
        return
    end

    local quantity = tonumber(words[2]) or 1
    local quality = tonumber(words[3]) or 333
    local data = {}
    for i = 4, #words do
        local key, value = words[i]:match("^([^=]+)=(.*)$")
        if key ~= nil then
            data[key] = value
        end
    end

    local rest = character:createItem(itemId, quantity, quality, data)
    if rest > 0 then
        character:inform("Nicht genug Platz, Restmenge: " .. rest, "Not enough space, remaining count: " .. rest)
        return
    end

    character:inform("Item erstellt.", "Item created.")
end

local function handleSpawn(character, args)
    local monsterId = tonumber(trim(args))
    if monsterId == nil then
        character:inform("Benutzung: !spawn <monsterId>", "Usage: !spawn <monsterId>")
        return
    end

    local pos = position(character.pos.x + 1, character.pos.y, character.pos.z)
    world:createMonster(monsterId, pos, 0)
    character:inform("Monster erstellt.", "Monster created.")
end

local function handleJumpTo(character, args)
    local target = findCharacterByName(args)
    if not target then
        character:inform("*** Spieler nicht gefunden.", "*** Player not found.")
        return
    end
    if target.id == character.id then
        return
    end

    character:forceWarp(target.pos)
    character:inform("Teleportiert zu " .. target.name .. ".", "Jumped to " .. target.name .. ".")
end

local function handleWarp(character, args)
    local numbers = {}
    for value in args:gmatch("-?%d+") do
        table.insert(numbers, tonumber(value))
    end

    if #numbers == 0 then
        character:inform("Benutzung: !warp <x> <y> [z] | !warp <z>", "Usage: !warp <x> <y> [z] | !warp <z>")
        return
    end

    local pos = character.pos
    local target
    if #numbers == 1 then
        target = position(pos.x, pos.y, numbers[1])
    elseif #numbers == 2 then
        target = position(numbers[1], numbers[2], pos.z)
    else
        target = position(numbers[1], numbers[2], numbers[3])
    end

    character:forceWarp(target)
    character:inform(string.format("Warped to x%d y%d z%d.", target.x, target.y, target.z))
end

local function handleSummon(character, args)
    local target = findCharacterByName(args)
    if not target then
        character:inform("*** Spieler nicht gefunden.", "*** Player not found.")
        return
    end
    if target.id == character.id then
        return
    end

    target:warp(character.pos)
    character:inform("Beschworen: " .. target.name, "Summoned: " .. target.name)
end

local function handleTile(character, args)
    local tileId = tonumber(trim(args))
    if tileId == nil then
        character:inform("Benutzung: !tile <tileId>", "Usage: !tile <tileId>")
        return
    end

    local front = character.SeleneEntity:getCoordinate():offset(character.SeleneEntity:getFacing())
    world:changeTile(tileId, front)
    character:inform("Tile geaendert.", "Tile changed.")
end

local function handleClipping(character, enabled)
    character:setClippingActive(enabled)
    if enabled then
        character:inform("Clipping aktiviert.", "Clipping enabled.")
    else
        character:inform("Clipping deaktiviert.", "Clipping disabled.")
    end
end

local function handleWhat(character)
    local front = character.SeleneEntity:getCoordinate():offset(character.SeleneEntity:getFacing())
    local field = world:getField(front)

    character:inform("Facing:")
    character:inform(string.format("- Position (%d,%d,%d)", front.x, front.y, front.z))
    if world:isPersistentAt(front) then
        character:inform("- Field is persistent.")
    end
    character:inform("- Tile " .. field:tile())
    character:inform(field:isPassable() and "- Field is passable." or "- Field blocks movement.")
    if field:isWarp() then
        character:inform("- Field has a warp annotation.")
    end

    local item = world:getItemOnField(front)
    if item.id ~= 0 then
        character:inform("- Item " .. item.id .. ", Stack of " .. item.number .. ", Wear " .. item.wear)
    end

    local target = world:getCharacterOnField(front)
    if target ~= nil then
        local targetType = target:getType()
        if targetType == Character.player then
            character:inform("- Player " .. target.name)
        elseif targetType == Character.monster then
            local monsterData = target.SeleneEntity:getRuntimeData(DataKeys.Character)
            local monsterDef = monsterData[DataFields.Monster]
            character:inform("- Monster " .. (monsterDef and monsterDef:getMetadata("id") or target.id))
        elseif targetType == Character.npc then
            character:inform("- NPC " .. target.id)
        else
            character:inform("- Character " .. target.id)
        end
    end
end

local COMMANDS

local function handleGmHelp(character)
    character:inform("<> - parameter. [] - optional. () = shortcut")
    for _, command in ipairs(COMMANDS) do
        if command.help then
            character:inform(command.help)
        end
    end
end

COMMANDS = {
    {
        names = {"gm"},
        help = "!gm <message> - Pages the GM team.",
        handler = handleGm,
    },
    {
        names = {"language", "l"},
        help = "!language <language> - (!l) sets your active language.",
        handler = handleLanguage,
    },
    {
        names = {"version", "v"},
        help = "!version - (!v) shows the server version.",
        handler = handleVersion,
    },
    {
        names = {"what"},
        help = "!what - Shows information about the field in front of you.",
        handler = handleWhat,
        requireAdmin = true,
    },
    {
        names = {"who"},
        help = "!who [player] - Lists all players online or details for one player.",
        handler = handleWho,
        requireAdmin = true,
    },
    {
        names = {"forceintroduce", "fi"},
        help = "!forceintroduce <player> - (!fi) introduces a player to you.",
        handler = handleForceIntroduce,
        requireAdmin = true,
    },
    {
        names = {"forceintroduceall", "fia"},
        help = "!forceintroduceall - (!fia) introduces all visible players to you.",
        handler = handleForceIntroduceAll,
        requireAdmin = true,
    },
    {
        names = {"talkto", "tt"},
        help = "!talkto <player>, <message> - (!tt) sends a direct admin message.",
        handler = handleTalkTo,
        requireAdmin = true,
    },
    {
        names = {"broadcast", "bc"},
        help = "!broadcast <message> - (!bc) sends a global message.",
        handler = handleBroadcast,
        requireAdmin = true,
    },
    {
        names = {"create"},
        help = "!create <id|name> [quantity [quality [key=value ...]]] - creates an item in your inventory.",
        handler = handleCreate,
        requireAdmin = true,
    },
    {
        names = {"spawn"},
        help = "!spawn <monsterId> - creates a monster next to you.",
        handler = handleSpawn,
        requireAdmin = true,
    },
    {
        names = {"jumpto", "j"},
        help = "!jumpto <player> - (!j) teleports you to the player.",
        handler = handleJumpTo,
        requireAdmin = true,
    },
    {
        names = {"warp", "w"},
        help = "!warp <x> <y> [z] | !warp <z> - (!w) changes your coordinates.",
        handler = handleWarp,
        requireAdmin = true,
    },
    {
        names = {"summon"},
        help = "!summon <player> - summons a player to your position.",
        handler = handleSummon,
        requireAdmin = true,
    },
    {
        names = {"tile"},
        help = "!tile <tileId> - changes the tile in front of you.",
        handler = handleTile,
        requireAdmin = true,
    },
    {
        names = {"clippingon"},
        help = "!clippingon / !clippingoff - toggles clipping.",
        handler = function(character) handleClipping(character, true) end,
        requireAdmin = true,
    },
    {
        names = {"clippingoff"},
        handler = function(character) handleClipping(character, false) end,
        requireAdmin = true,
    },
    {
        names = {"gmhelp"},
        handler = handleGmHelp,
        requireAdmin = true,
    },
}

local function findCommand(commandName)
    for _, command in ipairs(COMMANDS) do
        for _, name in ipairs(command.names) do
            if name == commandName then
                return command
            end
        end
    end
    return nil
end

function m.handle(character, message)
    if type(message) ~= "string" or message:sub(1, 1) ~= "!" then
        return false
    end

    local commandLine = trim(message:sub(2))
    if commandLine == "" then
        return true
    end

    local command, args = commandLine:match("^(%S+)%s*(.-)$")
    if not command then
        return true
    end

    command = command:lower()
    args = trim(args or "")

    local commandDefinition = findCommand(command)
    if commandDefinition == nil then
        informUnknown(character, command)
        return true
    end

    if commandDefinition.requireAdmin and not requireAdmin(character, "!" .. commandLine) then
        return true
    end

    commandDefinition.handler(character, args)
    return true
end

return m
