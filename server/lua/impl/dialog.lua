Character.SeleneMethods.requestMessageDialog = function(user, dialog)
    print("requestMessageDialog", user.name, table.tostring(dialog))
    user:inform(dialog.message)
end
