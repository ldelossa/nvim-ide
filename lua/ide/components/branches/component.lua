local base       = require('ide.panels.component')
local tree       = require('ide.trees.tree')
local git        = require('ide.lib.git.client').new()
local libbuf     = require("ide.lib.buf")
local libws      = require('ide.lib.workspace')
local gitutil    = require('ide.lib.git.client')
local branchnode = require('ide.components.branches.branchnode')
local commands   = require('ide.components.branches.commands')
local logger     = require('ide.logger.logger')
local icons      = require('ide.icons')

local BranchesComponent = {}

local config_prototype = {
    default_height = nil,
    disabled_keymaps = false,
    keymaps = {
        expand = "zo",
        collapse = "zc",
        collapse_all = "zM",
        jump = "<CR>",
        create_branch = "c",
        refresh = "r",
        hide = "<C-[>",
        close = "X",
        details = "d",
        pull = "p",
        push = "P",
        set_upstream = "s"
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

    -- seup config, use default and merge in user config if not nil
    self.config = vim.deepcopy(config_prototype)
    if config ~= nil then
        self.config = vim.tbl_deep_extend("force", config_prototype, config)
    end

    self.hidden = false

    self.refresh_aucmd = nil

    -- we register fs events for .git/HEAD and .git/refs/heads to identify when
    -- branches are modified or checked out.
    self.fsevents = {
        vim.loop.new_fs_event(),
        vim.loop.new_fs_event()
    }

    -- the HEAD file is re-created each time a branch change occurs, which breaks
    -- the watch on the inode, must be recreated each time.
    local function register_head_fs_event()
        self.fsevents[1]:stop()
        self.fsevents[1] = vim.loop.new_fs_event()
        self.fsevents[1]:start(vim.fn.fnamemodify(".git/HEAD", ':p'), {}, vim.schedule_wrap(function()
            if not libws.is_current_ws(self.workspace) then
                return
            end
            if libbuf.is_regular_buffer(0) then
                self.get_branches()
            end
            register_head_fs_event()
        end))
    end

    register_head_fs_event()

    -- watching on the heads/ directory, so no special case like above.
    self.fsevents[2]:start(vim.fn.fnamemodify(".git/refs/heads", ':p'), {}, vim.schedule_wrap(function()
        if not libws.is_current_ws(self.workspace) then
            return
        end
        if libbuf.is_regular_buffer(0) then
            self.get_branches()
        end
    end))

    local function setup_buffer()
        local log = self.logger.logger_from(nil, "Component._setup_buffer")
        local buf = vim.api.nvim_create_buf(false, true)

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
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.create_branch, "",
                { silent = true, callback = function() self.create_branch() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.refresh, "",
                { silent = true, callback = function() self.get_branches() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.hide, "",
                { silent = true, callback = function() self.hide() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.details, "",
                { silent = true, callback = function() self.details() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.pull, "",
                { silent = true, callback = function() self.pull_branch() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.push, "",
                { silent = true, callback = function() self.push_branch() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.set_upstream, "",
                { silent = true, callback = function() self.set_upstream() end })
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
        icons.global_icon_set.set_win_highlights()
    end

    -- implements @Component interface
    function self.get_commands()
        log = self.logger.logger_from(nil, "Component.get_commands")
        return commands.new(self).get()
    end

    function self.get_branches()
        git.if_in_git_repo(function()
            local cur_tab = vim.api.nvim_get_current_tabpage()
            local repo = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
            if self.workspace.tab ~= cur_tab then
                return
            end
            git.branch(function(branches)
                if branches == nil or #branches == 0 then
                    return
                end
                local children = { {} } -- reserve first item for head.
                for _, branch in ipairs(branches) do
                    local node = branchnode.new(branch.sha, branch.branch, branch.is_head)
                    node.remote = branch.remote
                    node.remote_branch = branch.remote_branch
                    node.remote_ref = branch.remote_ref
                    node.tracking = branch.tracking
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

    function self.create_branch(args)
        if not gitutil.in_git_repo() then
            vim.notify("Must be in a git repo to create a branch", "error", {
                title = "Branches",
            })
            return
        end

        vim.ui.input(
            {
                prompt = "Enter a branch name: "
            },
            function(branch)
                if branch == nil or branch == "" then
                    return
                end
                git.checkout_branch(branch, function(ok)
                    self.get_branches()
                end)
            end
        )
    end

    function self.pull_branch(args)
        if not gitutil.in_git_repo() then
            vim.notify("Must be in a git repo to create a branch", "error", {
                title = "Branches",
            })
            return
        end

        local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if node == nil then
            return
        end

        if node.remote == "" or node.remote == nil then
            vim.notify("Local branch is not tracking remote branch.", "error", {
                title = "Branches",
            })
            return
        end

        git.pull(node.remote, node.remote_branch, function(success)
            if success == nil then
                return
            end
            self.get_branches()
            vim.notify(string.format("Pulled latest branch: %s from remote: %s", node.branch, node.remote), "info", {
                title = "Branches",
            })
        end)
    end

    function self.push_branch(args)
        if not gitutil.in_git_repo() then
            vim.notify("Must be in a git repo to create a branch", "error", {
                title = "Branches",
            })
            return
        end

        local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if node == nil then
            return
        end

        if node.remote == "" or node.remote == nil then
            vim.notify("Local branch is not tracking remote branch.", "error", {
                title = "Branches",
            })
            return
        end

        git.push(node.remote, node.remote_branch, function(success)
            if success == nil then
                return
            end
            self.get_branches()
            vim.notify(string.format("Pushed branch: %s to remote: %s", node.branch, node.remote), "info", {
                title = "Branches",
            })
        end)
    end

    function self.set_upstream(args)
        if not gitutil.in_git_repo() then
            vim.notify("Must be in a git repo to create a branch", "error", {
                title = "Branches",
            })
            return
        end

        local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if node == nil then
            return
        end

        vim.ui.input({
            prompt = "Set upstream to (remote/branch): ",
            default = "origin/" .. node.branch,
        }, function(input)
            if input == nil or input == "" then
                return
            end
            git.set_upstream(node.branch, input, function(resp)
                if resp ~= nil then
                    self.get_branches()
                end
            end)
        end)

    end

    self.refresh_aucmd = vim.api.nvim_create_autocmd({ "BufEnter" }, {
        callback = function()
            if not libws.is_current_ws(self.workspace) then
                return
            end
            if libbuf.is_regular_buffer(0) then
                self.get_branches()
            end
        end
    })

    return self
end

return BranchesComponent
