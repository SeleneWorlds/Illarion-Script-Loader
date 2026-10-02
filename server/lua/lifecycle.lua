local Server = require("selene.server")
local Players = require("selene.players")
local Config = require("selene.config")
local Network = require("selene.network")
local Schedules = require("selene.schedules")

local PlayerManager = require("illarion-script-loader.server.lua.lib.playerManager")
local CharacterPersistence = require("illarion-script-loader.server.lua.lib.characterPersistence")
local CharacterCreation = require("illarion-script-loader.server.lua.lib.characterCreation")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")
local SkillManager = require("illarion-script-loader.server.lua.lib.skillManager")
local MonsterManager = require("illarion-script-loader.server.lua.lib.monsterManager")
local MagicManager = require("illarion-script-loader.server.lua.lib.magicManager")

local common = require("base.common")
local illaReloadOk, illaReload = pcall(require, "server.reload")
local illaReloadDefsOk, illaReloadDefs = pcall(require, "server.reload_defs")
local illaReloadTablesOk, illaReloadTables = pcall(require, "server.reload_tables")
local illaLogin = require("server.login")
local illaLogout = require("server.logout")

local CHARACTER_SAVE_INTERVAL_MS = 5 * 60 * 1000

local function sendCharacters(player)
    Network.sendToPlayer(player, "illarion:characters", {
        characters = CharacterPersistence.loadCharacterSummaries(player)
    })
end

local function finishLogin(player, selectedCharacter)
    local character = PlayerManager.Spawn(player, selectedCharacter)
    if Config.getProperty("showWelcomeMessage") == "true" then
        local otherPlayerCount = #world:getPlayersOnline() - 1
        local welcomeMessageDe = ":) Willkommen in Illarion, es sind " .. otherPlayerCount .. " andere Spieler online."
        local welcomeMessageEn = ":) Welcome to Illarion. There are " .. otherPlayerCount .. " other players online."
        common.InformNLS(character, welcomeMessageDe, welcomeMessageEn)
    end

    illaLogin.onLogin(character)
    SkillManager.SendAll(character)
    MagicManager.SendMagicState(character)
end

Players.playerQueued:connect(function(entry)
    local userId = entry:getUserId()
    if not PlayerManager.IsAdminUserId(userId) and PlayerManager.IsUserOnline(userId) then
        entry:reject("This account is already logged in.")
    else
        entry:accept()
    end
end)

Players.playerJoined:connect(function(player)
    sendCharacters(player)
end)

Network.handlePayload("illarion:request_characters", function(player)
    if not player:getControlledEntity() then
        sendCharacters(player)
    end
end)

Network.handlePayload("illarion:request_character_creation", function(player)
    if not player:getControlledEntity() then
        Network.sendToPlayer(
            player,
            "illarion:character_creation_options",
            CharacterCreation.getOptions(true, player:getLocale())
        )
    end
end)

Network.handlePayload("illarion:create_character", function(player, payload)
    if player:getControlledEntity() then
        return
    end
    local data, validationError = CharacterCreation.validate(payload)
    if not data then
        Network.sendToPlayer(player, "illarion:character_creation_result", { error = validationError })
        return
    end
    local ok, id, creationError = pcall(CharacterCreation.create, player, data)
    if not ok then
        Network.sendToPlayer(player, "illarion:character_creation_result", { error = "Character creation failed." })
        return
    end
    if not id then
        Network.sendToPlayer(player, "illarion:character_creation_result", { error = creationError })
        return
    end
    Network.sendToPlayer(player, "illarion:character_creation_result", { id = id })
    sendCharacters(player)
end)

Network.handlePayload("illarion:select_character", function(player, payload)
    if player:getControlledEntity() then
        return
    end

    local selectedId = PayloadValidation.integer(payload.id, 0)
    if not selectedId then
        return
    end
    for _, ownedCharacter in ipairs(CharacterPersistence.loadCharacterSummaries(player)) do
        if ownedCharacter.id == selectedId then
            if PlayerManager.IsCharacterOnline(selectedId) then
                player:kick("This character is already logged in.")
                return
            end
            local character = CharacterPersistence.loadCharacter(player, selectedId)
            if not character then
                return
            end
            finishLogin(player, character)
            Network.sendToPlayer(player, "illarion:character_selected", {
                id = ownedCharacter.id
            })
            return
        end
    end
end)

Players.playerLeft:connect(function(player)
    if player:getControlledEntity() then
        local character = Character.fromSelenePlayer(player)
        character:abortAction()
        illaLogout.onLogout(character)
        CharacterPersistence.saveCharacter(player, character)
    end
    PlayerManager.Despawn(player)
end)

Schedules.setInterval(CHARACTER_SAVE_INTERVAL_MS, function()
    for _, player in ipairs(Players.getOnlinePlayers()) do
        if player:getControlledEntity() then
            CharacterPersistence.saveCharacter(player, Character.fromSelenePlayer(player))
        end
    end
end)

Server.bundleUnloading:connect(function()
    MonsterManager.RemoveAll()
end)

Server.serverReloaded:connect(function()
    if illaReloadOk then
        illaReload.onReload()
    end
    if illaReloadDefsOk then
        illaReloadDefs.onReload()
    end
    if illaReloadTablesOk then
        illaReloadTables.onReload()
    end
end)
