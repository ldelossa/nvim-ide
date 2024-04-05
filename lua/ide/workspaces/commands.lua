local panel              = require('ide.panels.panel')
local libcmd             = require('ide.lib.commands')

local Commands = {}

Commands.new = function(ws)
    local self = {
        -- The workspace which this Commands structure delegates to.
        workspace = ws,
    }

    -- Retrieves all commands exported by the Workspaces modules.
    --
    -- These three items can be directly used directly with nvim_create_user_command
    -- or invoked directly by a caller.
    --
    -- return: @table, a command description containing the following fields:
    --         @shortname - @string, A name used when displayed by a subcommand
    --         @name - @string, A unique name of the command used outside the context
    --         of a sub command
    --         @callback - @function(args), A callback function which implements
    --         the command, args a table described in ":h nvim_create_user_command()"
    --         @opts - @table, the options table as described in ":h nvim_create_user_command()"
    function self.get()
        local commands = {
            libcmd.new(
                libcmd.KIND_ACTION,
                "WorkspaceLeftPanelToggle",
                "LeftPanelToggle",
                function(_) ws.toggle_panel(panel.PANEL_POS_LEFT) end,
                { desc = "Toggles the top panel in the current workspace."}
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "WorkspaceRightPanelToggle",
                "RightPanelToggle",
                function(_) ws.toggle_panel(panel.PANEL_POS_RIGHT) end,
                { desc = "Toggles the top panel in the current workspace."}
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "WorkspaceBottomPanelToggle",
                "BottomPanelToggle",
                function(_) ws.toggle_panel(panel.PANEL_POS_BOTTOM) end,
                { desc = "Toggles the top panel in the current workspace."}
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "WorkspaceLeftPanelClose",
                "LeftPanelClose",
                function(_) ws.close_panel(panel.PANEL_POS_LEFT) end,
                { desc = "Closes the left panel in the current workspace."}
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "WorkspaceRightPanelClose",
                "RightPanelClose",
                function(_) ws.close_panel(panel.PANEL_POS_RIGHT) end,
                { desc = "Closes the right panel in the current workspace."}
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "WorkspaceBottomPanelClose",
                "BottomPanelClose",
                function(_) ws.close_panel(panel.PANEL_POS_BOTTOM) end,
                { desc = "Closes the bottom panel in the current workspace."}
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "WorkspaceMaximizeComponent",
                "MaximizeComponent",
                function(_) ws.maximize_component() end,
                { desc = "Maximize the component your cursor is in."}
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "WorkspaceReset",
                "Reset",
                function(_) ws.equal_components() end,
                { desc = "Set all component windows to equal sizes or their user specified default heights"}
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "WorkspaceSwapPanel",
                "SwapPanel",
                function(_) ws.select_swap_panel() end,
                { desc = "Swap a panel with another panel group."}
            ),
            libcmd.new(
                libcmd.KIND_ACTION,
                "WorkspaceOpenLog",
                "OpenLog",
                function(_) require('ide.logger.logger').open_log() end,
                { desc = "Open nvim-ide's log in a new tab."}
            ),
        }
        return commands
    end

    return self
end


return Commands
