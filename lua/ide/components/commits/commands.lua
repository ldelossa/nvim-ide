local libcmd = require('ide.lib.commands')

local Commands = {}

Commands.new = function(commits)
    assert(commits ~= nil, "Cannot construct Commands without an Commits instance.")
    local self = {
        -- An instance of an Explorer component which Commands delegates to.
        commits = commits,
    }

    -- returns a list of @Command(s) defined in 'ide.lib.commands'
    --
    -- @return: @table, an array of @Command(s) which export an Commits's
    -- command set.
    function self.get()
        local commands = {
            libcmd.new(
                libcmd.KIND_ACTION,
                "CommitsFocus",
                "Focus",
                self.commits.focus,
                { desc = "Open and focus the Commits." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "CommitsHide",
                "Hide",
                self.commits.hide,
                { desc = "Hide the commits in its current panel. Use Focus to unhide." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "CommitsMinimize",
                "Minimize",
                self.commits.minimize,
                { desc = "Minimize the commits window in its panel." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "CommitsMaximize",
                "Maximize",
                self.commits.maximize,
                { desc = "Maximize the commits window in its panel." }
            ),
        }
        return commands
    end

    return self
end

return Commands
