local base = require('ide.panels.component')
local tree = require('ide.trees.tree')
local git = require('ide.lib.git.client').new()
local branchnode = require('ide.components.branches.branchnode')
local commands = require('ide.components.branches.commands')
local logger = require('ide.logger.logger')
local icon_set = require('ide.icons').global_icon_set

BranchesComponent = {}

local config_prototype = {
    disabled_keymaps = false,
    keymaps = {
        expand = "zo",
        collapse = "zc",
        collapse_all = "zM",
        jump = "<CR>",
        refresh = "r",
        hide = "<C-[>",
        close = "X",
        details = "d",
        maximize = "+",
        minimize = "-"
    },
}

-- BranchesComponent is a derived @Component implementing a tree of incoming
-- or outgoing calls.
-- Must implement:
--  @Component.open
--  @Component.post_win_create
--  @Component.close
--  @Component.get_commands
BranchesComponent.new = function(name, config)
    -- extends 'ide.panels.Component' fields.
    local self = base.new(name)

    -- a @Tree containing the current buffer's document symbols.
    self.tree = tree.new("branches")

    -- a logger that will be used across this class and its base class methods.
    self.logger = logger.new("branches")

    -- TODO: merge incoming config object.
    self.config = vim.deepcopy(config_prototype)

    self.hidden = false

    local function setup_buffer()
        local log = self.logger.logger_from(nil, "Component._setup_buffer")
        local buf = vim.api.nvim_create_buf(true, true)

        vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
        vim.api.nvim_buf_set_option(buf, 'filetype', 'filetree')
        vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        vim.api.nvim_buf_set_option(buf, 'swapfile', false)
        vim.api.nvim_buf_set_option(buf, 'textwidth', 0)
        vim.api.nvim_buf_set_option(buf, 'wrapmargin', 0)

        if not self.config.disable_keymaps then
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.expand, "",
                { silent = true, callback = function() self.expand() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.collapse, "",
                { silent = true, callback = function() self.collapse() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.collapse_all, "",
                { silent = true, callback = function() self.collapse_all() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.jump, "",
                { silent = true, callback = function() self.jump_branchnode({ fargs = {} }) end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.refresh, "",
                { silent = true, callback = function() self.get_branches() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.hide, "",
                { silent = true, callback = function() self.hide() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.details, "",
                { silent = true, callback = function() self.details() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.maximize, "", { silent = true,
                callback = self.maximize })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.minimize, "", { silent = true,
                callback = self.minimize })
        end

        return buf
    end

    self.buf = setup_buffer()

    self.tree.set_buffer(self.buf)

    -- implements @Component.open()
    function self.open()
        if self.tree.root == nil then
            self.get_branches()
        end
        return self.buf
    end

    -- implements @Component interface
    function self.post_win_create()
        local log = self.logger.logger_from(nil, "Component.post_win_create")
        icon_set.set_win_highlights()
    end

    -- implements @Component interface
    function self.get_commands()
        log = self.logger.logger_from(nil, "Component.get_commands")
        return commands.new(self).get()
    end

    function self.get_branches()
        local cur_buf = vim.api.nvim_get_current_buf()
        local cur_tab = vim.api.nvim_get_current_tabpage()
        local repo = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
        if self.workspace.tab ~= cur_tab then
            return
        end
        git.branch(function(branches)
            if branches == nil then
                return
            end
            local children = {nil} -- reserve first item for head.
            for _, branch in ipairs(branches) do
                local node = branchnode.new(branch.sha, branch.branch, branch.is_head)
                if node.is_head then
                    children[1] = node
                    goto continue
                end
                table.insert(children, node)
                ::continue::
            end
            local root = branchnode.new("", repo, false, 0)
            self.tree.add_node(root, children)
            self.tree.marshal({ no_guides_leafs = true, virt_text_pos = "eol" })
        end)
    end

    function self.jump_branchnode(args)
        log = self.logger.logger_from(nil, "Component.jump_branchnode")

        local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if node == nil then
            return
        end

        git.checkout(node.branch, function()
            self.get_branches()
            local commits = self.workspace.search_component("Commits")
            if commits ~= nil then
                commits.component.get_commits()
            end
        end)
    end

    return self
end

return BranchesComponent
