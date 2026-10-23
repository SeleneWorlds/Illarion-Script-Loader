local Server = require("selene.server")
local MapPersistence = require("illarion-script-loader.server.lua.lib.mapPersistence")

Server.serverReloaded:connect(MapPersistence.initialize)
