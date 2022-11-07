local libcmd = require('ide.lib.commands')

local Commands = {}

Commands.new = function(terminalbrowser)
    assert(terminalbrowser ~= nil, "Cannot construct Commands without an TerminalBrowser instance.")
    local self = {
        -- An instance of an Explorer component which Commands delegates to.
        terminalbrowser = terminalbrowser,
    }

    -- returns a list of @Command(s) defined in 'ide.lib.commands'
    --
    -- @return: @table, an array of @Command(s) which export an TerminalBrowser's
    -- command set.
    function self.get()
        local commands = {
            libcmd.new(
                libcmd.KIND_ACTION,
                "TerminalBrowserFocus",
                "Focus",
                self.terminalbrowser.focus,
                { desc = "Open and focus the TerminalBrowser." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "TerminalBrowserHide",
                "Hide",
                self.terminalbrowser.hide,
                { desc = "Hide the terminal in its current panel. Use Focus to unhide." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "TerminalBrowserMinimize",
                "Minimize",
                self.terminalbrowser.minimize,
                { desc = "Minimize the terminal window in its panel." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "TerminalBrowserMaximize",
                "Maximize",
                self.terminalbrowser.maximize,
                { desc = "Maximize the terminal window in its panel." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "TerminalBrowserNew",
                "New",
                self.terminalbrowser.new_term,
                { desc = "Open a new terminal" }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "TerminalBrowserRename",
                "Rename",
                self.terminalbrowser.rename_term,
                { desc = "Rename (or set) a terminal's name" }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "TerminalBrowserDelete",
                "Delete",
                self.terminalbrowser.delete_term,
                { desc = "Rename (or set) a terminal's name" }
            ),
        }
        return commands
    end

    return self
end

return Commands
