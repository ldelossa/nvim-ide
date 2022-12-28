local default_names = {
    BufferList = "BufferList",
    Explorer = "Explorer",
    Outline = "Outline",
    CallHierarchy = "CallHierarchy",
    Bookmarks = "Bookmarks",
    TerminalBrowser = "TerminalBrowser",
    Terminal = "Terminal",
    Changes = "Changes",
    Commits = "Commits",
    Timeline = "Timeline",
    Branches = "Branches",
}

local M = {}

-- The default config which will be merged with the `config` provided to setup()
--
-- The user provided config may just provide the values they'd like to override
-- and can omit any defaults.
--
-- Modules can read from this field to get config values. For example
-- require('ide').config.
M.config = {
    default_names = default_names,
    -- The global icon set to use.
    -- values: "nerd", "codicon", "default"
    icon_set = "default",
    -- Component specific configurations and default config overrides.
    components = {
        -- The global keymap is applied to all Components before construction.
        -- It allows common keymaps such as "hide" to be overriden, without having
        -- to make an override entry for all Components.
        --
        -- If a more specific keymap override is defined for a specific Component
        -- this takes precedence.
        global_keymaps = {
            -- example, change all Component's hide keymap to "h"
            -- hide = h
        },
        -- example, prefer "x" for hide only for Explorer component.
        -- Explorer = {
        --     keymaps = {
        --         hide = "x",
        --     }
        -- }
    },
    -- default panel groups to display on left and right.
    panels = {
        left = "explorer",
        right = "git"
    },
    -- panels defined by groups of components, user is free to redefine the defaults
    -- and/or add additional.
    panel_groups = {
        explorer = {
            default_names.BufferList,
            default_names.Explorer,
            default_names.Outline,
            default_names.CallHierarchy,
            default_names.Bookmarks,
            default_names.TerminalBrowser,
        },
        terminal = { default_names.Terminal },
        git = { default_names.Changes, default_names.Commits, default_names.Timeline, default_names.Branches },
    },
    -- workspaces config
    workspaces = {
        -- which panels to open by default, one of: 'left', 'right', 'both', 'none'
        auto_open = 'left',
    },
    -- default panel sizes
    panel_sizes = {
        left = 30,
        right = 30,
        bottom = 15
    }
}

function M.setup(config)
    -- merge the incoming config with our global, forcing the right table's keys
    -- to overwrite the left's.
    M.config = vim.tbl_deep_extend("force", M.config, config)

    -- configure the global icon set.
    if M.config["icon_set"] == "nerd" then
        require('ide.icons').global_icon_set = require('ide.icons.nerd_icon_set').new()
    end
    if M.config["icon_set"] == "codicon" then
        require('ide.icons').global_icon_set = require('ide.icons.codicon_icon_set').new()
    end

    require("ide.components.bufferlist")
    require("ide.components.explorer")
    require("ide.components.outline")
    require("ide.components.callhierarchy")
    require("ide.components.timeline")
    require("ide.components.terminal")
    require("ide.components.terminal.terminalbrowser")
    require("ide.components.changes")
    require("ide.components.commits")
    require("ide.components.branches")
    require("ide.components.bookmarks")

    -- create and launch a workspace controller.
    local wsctrl = require('ide.workspaces.workspace_controller').new(M.config.workspaces)
    wsctrl.init()
end

return M
