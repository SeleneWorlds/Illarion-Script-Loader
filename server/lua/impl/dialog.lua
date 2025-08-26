Character.SeleneMethods.requestMessageDialog = function(user, dialog)
    print("requestMessageDialog", user.name, tablex.tostring(dialog))
    user:inform(dialog.message)
end
