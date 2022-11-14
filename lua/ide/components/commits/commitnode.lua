local node     = require('ide.trees.node')
local icon_set = require('ide.icons').global_icon_set
local logger   = require('ide.logger.logger')
local git      = require('ide.lib.git.client').new()
local libpopup = require('ide.lib.popup')

CommitNode = {}

CommitNode.new = function(sha, file, subject, author, date, depth)
    -- extends 'ide.trees.Node' fields.

    local key = string.format("%s:%s:%s:%s:%s", sha, file, subject, author, date)
    local self = node.new("git_commit", sha, sha, depth)

    -- CommitNodes make a list, not a tree, so just always expand and we'll set
    -- the tree to marshal with no leave guides.
    self.expanded = true
    self.sha = sha
    self.file = file
    self.subject = subject
    self.author = author
    self.date = date
    self.is_file = nil

    -- all nodes start as collapsed.
    self.expanded = false
    if self.depth == 0 then
        self.expanded = true
    end

    -- Marshal a commitnode into a buffer line.
    --
    -- @return: @icon - @string, icon used for call hierarchy item
    --          @name - @string, the name of the call hierarchy item
    --          @details - @string, the details of the call hierarchy item
    function self.marshal()
        local icon = icon_set.get_icon("GitCommit")
        if self.author == "" then
            icon = icon_set.get_icon("File")
        end
        if self.depth == 0 then
            icon = icon_set.get_icon("GitRepo")
        end

        local name = string.format("%s", self.subject)
        local detail = string.format("%s %s", self.author, self.date)
        if self.is_file then
            return icon, name, detail, ""
        end

        return icon, name, detail
    end

    function self.details()
        git.log(self.sha, 1, function(data)
            if data == nil then
                return
            end

            local commit = data[1]
            if commit == nil then
                return
            end

            local lines = {}
            table.insert(lines, string.format("%s %s", icon_set.get_icon("GitCommit"), commit.sha))
            table.insert(lines, string.format("%s %s", icon_set.get_icon("Account"), commit.author))
            table.insert(lines, string.format("%s %s", icon_set.get_icon("Calendar"), commit.date))
            table.insert(lines, "")

            local subject = vim.fn.split(commit.subject, "\n")
            table.insert(lines, subject[1])

            table.insert(lines, "")

            local body = vim.fn.split(commit.body, "\n")
            for _, l in ipairs(body) do
                table.insert(lines, l)
            end

            libpopup.until_cursor_move(lines)
        end)
    end

    function self.expand(cb)
        if self.is_file then
            return
        end
        git.show_ref_paths(self.sha, function(paths)
            if self.depth == 0 then
                self.expanded = true
                return
            end
            local children = {}
            for _, path in ipairs(paths) do
                local file = CommitNode.new(path.ref, path.path, path.path, "", "")
                file.is_file = true
                table.insert(children, file)
            end
            self.tree.add_node(self, children)
            self.expanded = true
            if cb ~= nil then
                cb()
            end
        end)
    end

    return self
end

return CommitNode
