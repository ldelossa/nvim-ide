local libcmd = require('ide.lib.commands')

local Commands = {}

Commands.new = function(terminal)
    assert(terminal ~= nil, "Cannot construct Commands without an Terminal instance.")
    local self = {
        -- An instance of an Explorer component which Commands delegates to.
        terminal = terminal,
    }

    -- returns a list of @Command(s) defined in 'ide.lib.commands'
    --
    -- @return: @table, an array of @Command(s) which export an Terminal's
    -- command set.
    function self.get()
        local commands = {
            libcmd.new(
                libcmd.KIND_ACTION,
                "TerminalFocus",
                "Focus",
                self.terminal.focus,
                { desc = "Open and focus the Terminal." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "TerminalHide",
                "Hide",
                self.terminal.hide,
                { desc = "Hide the terminal in its current panel. Use Focus to unhide." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "TerminalMinimize",
                "Minimize",
                self.terminal.minimize,
                { desc = "Minimize the terminal window in its panel." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "TerminalMaximize",
                "Maximize",
                self.terminal.maximize,
                { desc = "Maximize the terminal window in its panel." }
            ),
        }
        return commands
    end

    return self
end

return Commands
