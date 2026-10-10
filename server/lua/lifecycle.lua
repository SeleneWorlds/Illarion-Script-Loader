local Server = require("selene.server")
local Players = require("selene.players")
local Config = require("selene.config")
local Network = require("selene.network")
local Schedules = require("selene.schedules")
local Logging = require("selene.logging")
local Permissions = require("selene.permissions")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local Events = require("illarion-script-loader.server.lua.lib.events")

local PlayerManager = require("illarion-script-loader.server.lua.lib.playerManager")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
local CharacterPersistence = require("illarion-script-loader.server.lua.lib.characterPersistence")
local BanManager = require("illarion-script-loader.server.lua.lib.banManager")
local CharacterCreation = require("illarion-script-loader.server.lua.lib.characterCreation")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")
local SkillManager = require("illarion-script-loader.server.lua.lib.skillManager")
local MonsterManager = require("illarion-script-loader.server.lua.lib.monsterManager")
local NPCManager = require("illarion-script-loader.server.lua.lib.npcManager")
local MagicManager = require("illarion-script-loader.server.lua.lib.magicManager")

local common = require("base.common")
local illaReloadOk, illaReload = pcall(require, "server.reload")
local illaReloadDefsOk, illaReloadDefs = pcall(require, "server.reload_defs")
local illaReloadTablesOk, illaReloadTables = pcall(require, "server.reload_tables")
local illaLogin = require("server.login")
local illaLogout = require("server.logout")

-- Persisted character IDs start at 1; 0 is reserved for the headless selection button.
local HEADLESS_CHARACTER_ID = 0
local CHARACTER_SAVE_INTERVAL_MS = 5 * 60 * 1000

Permissions.setHandler(function(player, permission, context)
    return PlayerManager.IsAdminUserId(player:getUserId())
end)

local function sendCharacters(player)
    local characters = CharacterPersistence.loadCharacterSummaries(player)
    if PlayerManager.IsAdminUserId(player:getUserId()) then
        table.insert(characters, { id = HEADLESS_CHARACTER_ID, name = "Headless Login" })
    end
    Network.sendToPlayer(player, "illarion:characters", { characters = characters })
end

local function finishLogin(player, selectedCharacter)
    local character = PlayerManager.Spawn(player, selectedCharacter)
    if Config.getProperty("showWelcomeMessage") == "true" then
        local otherPlayerCount = 0
        for _, onlinePlayer in ipairs(Players.getOnlinePlayers()) do
            local entity = onlinePlayer:getControlledEntity()
            if onlinePlayer ~= player and entity
                    and not entity:getRuntimeData(DataKeys.Character)[DataFields.Headless] then
                otherPlayerCount = otherPlayerCount + 1
            end
        end
        local welcomeMessageDe = ":) Willkommen in Illarion, es sind " .. otherPlayerCount .. " andere Spieler online."
        local welcomeMessageEn = ":) Welcome to Illarion. There are " .. otherPlayerCount .. " other players online."
        common.InformNLS(character, welcomeMessageDe, welcomeMessageEn)
    end

    if not selectedCharacter.headless then
        illaLogin.onLogin(character)
    end
    SkillManager.SendAll(character)
    MagicManager.SendMagicState(character)
end

Players.playerQueued:connect(function(entry)
    local userId = entry:getUserId()
    local ban = BanManager.getAccountBan(userId)
    if ban then
        entry:reject(BanManager.message("account", ban))
    elseif not PlayerManager.IsAdminUserId(userId) and PlayerManager.IsUserOnline(userId) then
        entry:reject("This account is already logged in.")
    else
        entry:accept()
    end
end)

Players.playerJoined:connect(function(player)
    local ban = BanManager.getAccountBan(player:getUserId())
    if ban then
        player:kick(BanManager.message("account", ban))
        return
    end
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
        local errorMessage = tostring(id)
        Logging.error("Character creation failed: " .. errorMessage)
        Network.sendToPlayer(player, "illarion:character_creation_result", {
            error = "Character creation failed: " .. errorMessage
        })
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
    if selectedId == HEADLESS_CHARACTER_ID then
        if not PlayerManager.IsAdminUserId(player:getUserId()) then
            return
        end
        local ban = BanManager.getAccountBan(player:getUserId())
        if ban then
            player:kick(BanManager.message("account", ban))
            return
        end
        local headlessX, headlessY, headlessZ, followId
        if payload.headless ~= nil then
            if type(payload.headless) ~= "table" then return end
            if payload.headless.x ~= nil or payload.headless.y ~= nil or payload.headless.z ~= nil then
                headlessX, headlessY, headlessZ = PayloadValidation.coordinates(payload.headless)
                if headlessX == nil or math.abs(headlessX) > 2147483647
                        or math.abs(headlessY) > 2147483647 or math.abs(headlessZ) > 2147483647 then return end
            end
            if payload.headless.follow ~= nil then
                followId = PayloadValidation.integer(payload.headless.follow, 1, 2147483647)
                if followId == nil then return end
            end
        end
        finishLogin(player, PlayerManager.CreateHeadlessCharacter())
        if headlessX ~= nil then
            Character.fromSelenePlayer(player):warp(position(headlessX, headlessY, headlessZ))
        end
        Network.sendToPlayer(player, "illarion:character_selected", { id = selectedId })
        Events.onCharacterSelected:fire(player)
        local editorOk, editor = pcall(require, "moonlight-editor.server.lua.editor")
        if editorOk and not editor.isEnabled(player) then
            editor.toggle(player)
        end
        local followCharacter = followId and CharacterManager.GetCharacterById(followId)
        if followCharacter then
            player:setCameraEntity(followCharacter.SeleneEntity)
            player:setCameraToFollowTarget()
        elseif headlessX ~= nil then
            player:setCameraToCoordinate(
                position(headlessX, headlessY, headlessZ), player:getControlledEntity():getDimension()
            )
        end
        return
    end
    for _, ownedCharacter in ipairs(CharacterPersistence.loadCharacterSummaries(player)) do
        if ownedCharacter.id == selectedId then
            local accountBan = BanManager.getAccountBan(player:getUserId())
            local characterBan = BanManager.getCharacterBan(selectedId)
            if accountBan or characterBan then
                player:kick(BanManager.message(accountBan and "account" or "character", accountBan or characterBan))
                return
            end
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
            Events.onCharacterSelected:fire(player)
            return
        end
    end
end)

Players.playerLeft:connect(function(player)
    if player:getControlledEntity() then
        local character = Character.fromSelenePlayer(player)
        character:abortAction()
        if not player:getControlledEntity():getRuntimeData(DataKeys.Character)[DataFields.Headless] then
            illaLogout.onLogout(character)
        end
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
    NPCManager.RemoveAll()
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
