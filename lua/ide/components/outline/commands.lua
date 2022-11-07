local libcmd = require('ide.lib.commands')

local Commands = {}

Commands.new = function(outline)
    assert(outline ~= nil, "Cannot construct Commands without an Outline instance.")
    local self = {
        -- An instance of an Explorer component which Commands delegates to.
        outline = outline,
    }

    -- returns a list of @Command(s) defined in 'ide.lib.commands'
    --
    -- @return: @table, an array of @Command(s) which export an Outline's
    -- command set.
    function self.get()
        local commands = {
            libcmd.new(
                libcmd.KIND_ACTION,
                "OutlineFocus",
                "Focus",
                self.outline.focus,
                { desc = "Open and focus the Outline." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "OutlineHide",
                "Hide",
                self.outline.hide,
                { desc = "Hide the outline in its current panel. Use Focus to unhide." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "OutlineExpand",
                "Expand",
                self.outline.expand,
                { desc = "Expand the symbol under the current cursor." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "OutlineCollapse",
                "Collapse",
                self.outline.collapse,
                { desc = "Collapse the symbol under the current cursor." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "OutlineCollapseAll",
                "CollapseAll",
                self.outline.collapse_all,
                { desc = "Collapse the symbol under the current cursor." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "OutlineMinimize",
                "Minimize",
                self.outline.minimize,
                { desc = "Minimize the outline window in its panel." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "OutlineMaximize",
                "Maximize",
                self.outline.maximize,
                { desc = "Maximize the outline window in its panel." }
            ),
        }
        return commands
    end

    return self
end

return Commands
