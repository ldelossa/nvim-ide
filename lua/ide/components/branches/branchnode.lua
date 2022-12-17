local node     = require('ide.trees.node')
local icon_set = require('ide.icons').global_icon_set

local BranchNode = {}

BranchNode.new = function(sha, branch, is_head, depth)
    -- extends 'ide.trees.Node' fields.

    local key = string.format("%s:%s", sha, branch)
    local self = node.new("git_branch", branch, key, depth)

    self.sha = sha
    self.branch = branch
    self.is_head = is_head

    if self.depth == 0 then
        self.expanded = true
    end

    -- Marshal a branchnode into a buffer line.
    --
    -- @return: @icon - @string, icon used for call hierarchy item
    --          @name - @string, the name of the call hierarchy item
    --          @details - @string, the details of the call hierarchy item
    function self.marshal()
        local icon = icon_set.get_icon("GitBranch")
        local name = string.format("%s", self.branch)
        local detail = ""

        -- root is the file we are displaying the timeline for.
        if self.depth == 0 then
            icon = icon_set.get_icon("GitRepo")
            return icon, name, detail
        end

        if self.is_head then
            name = "* " .. name
        end

        if self.remote ~= nil then
            detail = self.remote
        end
        if self.remote_branch ~= nil then
            detail = detail .. self.remote_branch
        end
        if self.ahead ~= 0 then
            detail = detail .. "↑"
        end
        if self.behind ~= 0 then
            detail = detail .. "↓"
        end

        return icon, name, detail, ""
    end

    return self
end

return BranchNode
