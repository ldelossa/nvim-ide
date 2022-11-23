local node     = require('ide.trees.node')
local icon_set = require('ide.icons').global_icon_set

BranchNode = {}

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

        -- root is the file we are displaying the timeline for.
        if self.depth == 0 then
            icon = icon_set.get_icon("GitRepo")
        end

        local name = string.format("%s", self.branch)

        if self.is_head then
            name = "* " .. name
        end

        local detail = self.sha

        return icon, name, detail, ""
    end

    return self
end

return BranchNode
