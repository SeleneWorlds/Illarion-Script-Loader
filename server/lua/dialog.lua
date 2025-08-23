local Interface = require("illarion-api.server.lua.interface")

Character.SeleneMethods.requestMessageDialog = function(user, dialog)
    print("requestMessageDialog", user.name, table.tostring(dialog))
    user:inform(dialog.message)
end
