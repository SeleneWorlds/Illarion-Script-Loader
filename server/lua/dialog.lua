local Interface = require("illarion-api.server.lua.interface")

Interface.Dialog.RequestInput = function(user, dialog)
    print("RequestInput", user.name, table.tostring(dialog))
end

Interface.Dialog.ShowMessage = function(user, dialog)
    print("ShowMessage", user.name, table.tostring(dialog))
    user:inform(dialog.message)
end

Interface.Dialog.RequestSelection = function(user, dialog)
    print("RequestSelection", user.name, table.tostring(dialog))
end

Interface.Dialog.ShowMerchant = function(user, dialog)
    print("ShowMerchant", user.name, table.tostring(dialog))
end

Interface.Dialog.ShowCrafting = function(user, dialog)
    print("ShowCrafting", user.name, table.tostring(dialog))
end

Interface.Dialog.ShowBook = function(user, bookId)
    print("ShowBook", user.name, bookId)
end

Interface.Dialog.ShowCharDescription = function(user, charId, message)
    print("ShowCharDescription", user.name, charId, message)
end