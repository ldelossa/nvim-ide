local node = require('ide.trees.node')
local icon_set = require('ide.icons').global_icon_set
local workspace_registry = require('ide.workspaces.workspace_registry')

local StatusNode = {}

StatusNode.new = function(status, path, staged, depth)
    local key = string.format("%s:%s", staged, path)
    local self = node.new("status", status, key, depth)
    self.status = status
    self.path = path
    self.staged = staged
    self.is_dir = false

    -- Marshal a statusnode into a buffer line.
    --
    -- @return: @icon - @string, icon for status's kind
    --          @name - @string, status's name
    --          @details - @string, status's detail if exists.
    function self.marshal()
        local ws = workspace_registry.current_workspace()
        local changes_comp = ws.search_component("Changes").component

        if self.is_dir then
            local parts = vim.fn.split(self.path, "/")
            local icon = icon_set.get_icon("Folder")
            local name = parts[#parts] .. "/"
            local details = ""
            return icon, name, details
        end

        local icon = ""
        -- use webdev icons if possible
        if pcall(require, "nvim-web-devicons") then
            icon = require("nvim-web-devicons").get_icon(self.path, nil, {default=true})
        end
        if vim.fn.isdirectory(self.path) ~= 0 then
            icon = icon_set.get_icon("Folder")
        end
        if self.depth == 0 then
            icon = icon_set.get_icon("GitRepo")
        end
        if self.depth == 1 then
            icon = icon_set.get_icon("GitCompare")
        end

        local name = self.path
        if changes_comp.view == "tree" then
            name = vim.fn.fnamemodify(self.path, ":t")
        end

        local detail = self.status
        return icon, name, detail
    end

    return self
end

return StatusNode
