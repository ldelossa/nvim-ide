local libcmd = require('ide.lib.commands')

local Commands = {}

Commands.new = function(changes)
    assert(changes ~= nil, "Cannot construct Commands without an Changes instance.")
    local self = {
        -- An instance of an Explorer component which Commands delegates to.
        changes = changes,
    }

    -- returns a list of @Command(s) defined in 'ide.lib.commands'
    --
    -- @return: @table, an array of @Command(s) which export an Changes's
    -- command set.
    function self.get()
        local commands = {
            libcmd.new(
                libcmd.KIND_ACTION,
                "ChangesFocus",
                "Focus",
                self.changes.focus,
                { desc = "Open and focus the Changes." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ChangesHide",
                "Hide",
                self.changes.hide,
                { desc = "Hide the changes in its current panel. Use Focus to unhide." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ChangesMinimize",
                "Minimize",
                self.changes.minimize,
                { desc = "Minimize the changes window in its panel." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ChangesMaximize",
                "Maximize",
                self.changes.maximize,
                { desc = "Maximize the changes window in its panel." }
            ),
        }
        return commands
    end

    return self
end

return Commands
