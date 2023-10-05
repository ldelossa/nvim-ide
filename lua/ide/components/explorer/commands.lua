local libcmd = require('ide.lib.commands')

local Commands = {}

Commands.new = function(ex)
    assert(ex ~= nil, "Cannot construct Commands with an Explorer instance.")
    local self = {
        -- An instance of an Explorer component which Commands delegates to.
        explorer = ex,
    }

    -- returns a list of @Command(s) defined in 'ide.lib.commands'
    --
    -- @return: @table, an array of @Command(s) which export an Explorer's
    -- command set.
    function self.get()
        local commands = {
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerFocus",
                "Focus",
                self.explorer.focus_with_expand,
                { desc = "Open and focus the Explorer." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerHide",
                "Hide",
                self.explorer.hide,
                { desc = "Hide the explorer in its current panel. Use Focus to unhide." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerExpand",
                "Expand",
                self.explorer.expand,
                { desc = "Expand the directory under the current cursor." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerCollapse",
                "Collapse",
                self.explorer.collapse,
                { desc = "Collapse the directory under the current cursor." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerCollapseAll",
                "CollapseAll",
                self.explorer.collapse_all,
                { desc = "Collapse all directories up to root." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerEdit",
                "EditFile",
                self.explorer.open_filenode,
                { desc = "Open the file for editing under the current cursor." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerMinimize",
                "Minimize",
                self.explorer.minimize,
                { desc = "Minimize the explorer window in its panel." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerMaximize",
                "Maximize",
                self.explorer.maximize,
                { desc = "Maximize the Explorer window in its panel." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerNewFile",
                "NewFile",
                self.explorer.touch,
                { desc = "Create a new file at the current cursor." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerNewDir",
                "NewDir",
                self.explorer.mkdir,
                { desc = "Create a new directory at the current cursor." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerRename",
                "Rename",
                self.explorer.rename,
                { desc = "Rename the file at the current cursor." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerDelete",
                "Delete",
                self.explorer.rm,
                { desc = "Delete the file at the current cursor." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerCopy",
                "Copy",
                self.explorer.cp,
                { desc = "(Recurisve) Copy the selected files to the destination under the cursor." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerMove",
                "Move",
                self.explorer.mv,
                { desc = "(Recursive) Move the selected files to the destination under the cursor." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerSelect",
                "Select",
                self.explorer.select,
                { desc = "Select the file under the cursor for further action." }
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "ExplorerUnselect",
                "Unselect",
                self.explorer.unselect,
                { desc = "Unselect the file under the cursor for further action." }
            ),
        }
        return commands
    end

    return self
end

return Commands
