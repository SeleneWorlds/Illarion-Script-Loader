local Server = require("selene.server")
local Players = require("selene.players")
local Config = require("selene.config")
local Network = require("selene.network")

local PlayerManager = require("illarion-script-loader.server.lua.lib.playerManager")
local CharacterPersistence = require("illarion-script-loader.server.lua.lib.characterPersistence")

local common = require("base.common")
local illaReloadOk, illaReload = pcall(require, "server.reload")
local illaReloadDefsOk, illaReloadDefs = pcall(require, "server.reload_defs")
local illaReloadTablesOk, illaReloadTables = pcall(require, "server.reload_tables")
local illaLogin = require("server.login")
local illaLogout = require("server.logout")

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
end

Players.playerJoined:connect(function(player)
    sendCharacters(player)
end)

Network.handlePayload("illarion:request_characters", function(player)
    if not player:getControlledEntity() then
        sendCharacters(player)
    end
end)

Network.handlePayload("illarion:select_character", function(player, payload)
    if player:getControlledEntity() then
        return
    end

    local selectedId = tonumber(payload.id)
    for _, ownedCharacter in ipairs(CharacterPersistence.loadCharacterSummaries(player)) do
        if ownedCharacter.id == selectedId then
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
