local Network = require("selene.network")

Character.SeleneMethods.startMusic = function(user, id)
    Network.SendToEntity(user.SeleneEntity, "illarion:music", {
        musicId = id
    })
end

Character.SeleneMethods.defaultMusic = function()
    Network.SendToEntity(user.SeleneEntity, "illarion:music", {
        musicId = 0
    })
end