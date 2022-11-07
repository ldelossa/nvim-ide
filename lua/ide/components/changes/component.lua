local base = require('ide.panels.component')
local tree = require('ide.trees.tree')
local commands = require('ide.components.changes.commands')
local logger = require('ide.logger.logger')
local diff_buf = require('ide.buffers.diffbuffer')
local libwin = require('ide.lib.win')
local libbuf = require('ide.lib.buf')
local statusnode = require('ide.components.changes.statusnode')
local icon_set = require('ide.icons').global_icon_set
local git = require('ide.lib.git.client').new()

ChangesComponent = {}

local config_prototype = {
    disabled_keymaps = false,
    keymaps = {
        expand = "zo",
        collapse = "zc",
        collapse_all = "zM",
        restore = "r",
        add = "s",
        amend = "a",
        commit = "c",
        jump = "<CR>",
        jump_tab = "t",
        toggle_view = "v",
        hide = "<C-[>",
        close = "X",
        maximize = "+",
        minimize = "-"
    },
}

-- ChangesComponent is a derived @Component implementing a file explorer.
-- Must implement:
--  @Component.open
--  @Component.post_win_create
--  @Component.close
--  @Component.get_commands
ChangesComponent.new = function(name, config)
    -- extends 'ide.panels.Component' fields.
    local self = base.new(name)

    -- a @Tree containing the current buffer's document statuss.
    self.tree = tree.new("changes")

    -- a logger that will be used across this class and its base class methods.
    self.logger = logger.new("changes")

    self.config = vim.deepcopy(config_prototype)

    self.view = "list"

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
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.restore, "",
                { silent = true, callback = function() self.restore({ fargs = {} }) end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.add, "",
                { silent = true, callback = function() self.add({ fargs = {} }) end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.amend, "",
                { silent = true, callback = function() self.amend({ fargs = {} }) end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.commit, "",
                { silent = true, callback = function() self.commit({ fargs = {} }) end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.jump, "",
                { silent = true, callback = function() self.jump_statusnode({ fargs = {} }) end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.jump_tab, "",
                { silent = true, callback = function() self.jump_statusnode({ fargs = { "tab" } }) end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.toggle_view, "",
                { silent = true, callback = function() self.toggle_view() end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.hide, "",
                { silent = true, callback = function() self.hide() end })
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
        if self.tree.root ~= nil then
            self.tree.marshal({ no_guides_leaf = true })
        end
        return self.buf
    end

    -- implements @Component interface
    function self.post_win_create()
        local log = self.logger.logger_from(nil, "Component.post_win_create")

        -- setup web-dev-icons highlights if available
        if pcall(require, "nvim-web-devicons") then
            for _, icon_data in pairs(require("nvim-web-devicons").get_icons()) do
                local hl = "DevIcon" .. icon_data.name
                vim.cmd(string.format("syn match %s /%s/", hl, icon_data.icon))
            end
        end

        icon_set.set_win_highlights()
    end

    function self.expand(args)
        local log = self.logger.logger_from(nil, "Component.expand")
        if not libwin.win_is_valid(self.win) then
            return
        end
        local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if node == nil then
            return
        end
        self.tree.expand_node(node)
        self.tree.marshal({ no_guides_leaf = true })
        self.state["cursor"].restore()
    end

    function self.collapse(args)
        local log = self.logger.logger_from(nil, "Component.collapse")
        if not libwin.win_is_valid(self.win) then
            return
        end
        local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if node == nil then
            return
        end
        self.tree.collapse_node(node)
        self.tree.marshal({ no_guides_leaf = true })
        self.state["cursor"].restore()
    end

    function self.collapse_all(args)
        local log = self.logger.logger_from(nil, "Component.collapse_all")
        if not libwin.win_is_valid(self.win) then
            return
        end
        local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if node == nil then
            return
        end
        self.tree.collapse_subtree(self.tree.root)
        self.tree.marshal({ no_guides_leaf = true })
        self.state["cursor"].restore()
    end

    function _build_tree_recursive(tree, root, index, paths, stat, staged)
        if index == #paths then
            local to_use = nil
            if staged == "staged" then
                to_use = stat.staged_status
            end
            if staged == "unstaged" then
                to_use = stat.unstaged_status
            end
            if staged == "untracked" then
                to_use = stat.unstaged_status
            end

            local node = statusnode.new(to_use, stat.path, staged)
            self.tree.add_node(root, {node}, { append = true })
            return
        end

        local key = ""
        for i = 1, index, 1 do
            key = key .. paths[i] .. "/"
        end
        key = staged .. ":" .. key

        local node = tree.search_key(key)

        if node == nil then
            local path = vim.fn.split(key, ":")[2]
            local sn = statusnode.new("", path, staged)
            sn.is_dir = true
            tree.add_node(root, {sn}, { append = true })
            _build_tree_recursive(tree, sn, index + 1, paths, stat, staged)
            return
        end
        _build_tree_recursive(tree, node, index + 1, paths, stat, staged)
    end

    local function _build_tree_view(stats)
        local root = statusnode.new("", vim.fn.fnamemodify(vim.fn.getcwd(), ":t"), false, 0)
        local staged = statusnode.new("", "Staged Changes", false)
        local unstaged = statusnode.new("", "Unstaged Changes", false)
        local untracked = statusnode.new("", "Untracked Changes", false)
        local children = { staged, unstaged, untracked }
        self.tree.add_node(root, children)

        local staged_stats = {}
        local unstaged_stats = {}
        local untracked_stats = {}

        for _, stat in ipairs(stats) do
            if stat.unstaged_status == "?" or stat.staged_status == "?" then
                table.insert(untracked_stats, stat)
                goto continue
            end
            if stat.staged_status ~= " " then
                table.insert(staged_stats, stat)
            end
            if stat.unstaged_status ~= " " then
                table.insert(unstaged_stats, stat)
            end
            ::continue::
        end

        for _, stat in ipairs(unstaged_stats) do
            local paths = vim.fn.split(stat.path, "/")
            _build_tree_recursive(self.tree, unstaged, 1, paths, stat, "unstaged")
        end

        for _, stat in ipairs(staged_stats) do
            local paths = vim.fn.split(stat.path, "/")
            _build_tree_recursive(self.tree, staged, 1, paths, stat, "staged")
        end

        for _, stat in ipairs(untracked_stats) do
            local paths = vim.fn.split(stat.path, "/")
            _build_tree_recursive(self.tree, untracked, 1, paths, stat, "untracked")
        end

        self.tree.marshal({ no_guides_leaf = true })
        self.state["cursor"].restore()
    end

    local function _build_list_view(stats)
        local root = statusnode.new("", vim.fn.fnamemodify(vim.fn.getcwd(), ":t"), false, 0)
        local staged = statusnode.new("", "Staged Changes", false)
        local unstaged = statusnode.new("", "Unstaged Changes", false)
        local untracked = statusnode.new("", "Untracked Changes", false)
        local children = { staged, unstaged, untracked }
        self.tree.add_node(root, children)

        for _, stat in ipairs(stats) do
            if stat.unstaged_status == "?" or stat.staged_status == "?" then
                self.tree.add_node(untracked, { statusnode.new(stat.unstaged_status, stat.path, false) }, { append = true })
                goto continue
            end
            if stat.staged_status ~= " " then
                self.tree.add_node(staged, { statusnode.new(stat.staged_status, stat.path, true) }, { append = true })
            end
            if stat.unstaged_status ~= " " then
                self.tree.add_node(unstaged, { statusnode.new(stat.unstaged_status, stat.path, false) }, { append = true })
            end
            ::continue::
        end

        self.tree.marshal({ no_guides_leaf = true })
        self.state["cursor"].restore()
    end

    function self.event_handler(args)
        git.status(function(stats)
            if stats == nil then
                return
            end
            if self.view == "list" then
                _build_list_view(stats)
            else
                _build_tree_view(stats)
            end
        end)
    end

    function self.add(args)
        log = self.logger.logger_from(nil, "Component.add")

        local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if node == nil then
            return
        end

        git.git_add(node.path, function()
            self.event_handler()
        end)
    end

    function self.restore(args)
        log = self.logger.logger_from(nil, "Component.restore")

        local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if node == nil then
            return
        end

        git.git_restore(node.staged, node.path, function()
            self.event_handler()
        end)
    end

    function self.commit(args)
        local term = self.workspace.search_component("TerminalBrowser")
        if term == nil then
            return
        end
        term.component.new_term(nil, "git commit", "/bin/bash -c 'git commit -s'")
    end

    function self.amend(args)
        local term = self.workspace.search_component("TerminalBrowser")
        if term == nil then
            return
        end
        term.component.new_term(nil, "git commit", "/bin/bash -c 'git commit --amend'")
    end

    function self.jump_statusnode(args)
        log = self.logger.logger_from(nil, "Component.jump_statusnode")

        local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if node == nil then
            print("nope")
            return
        end

        local tab = false
        for _, arg in ipairs(args.fargs) do
            if arg == "tab" then
                tab = true
            end
        end

        local win = self.workspace.get_win()

        if tab then
            vim.cmd("tabnew")
        end

        -- if its untracked make it look like a new file diff.
        if node.status == "?" or node.status == "A" then
            local dbuff = diff_buf.new()
            dbuff.setup()
            local o = { listed = false, scratch = true, modifiable = false }
            dbuff.write_lines({}, "a", o)
            dbuff.open_buffer(node.path, "b")
            dbuff.diff()

            vim.api.nvim_set_current_win(self.win)
            return
        end

        local rev = ""

        -- if the commit is staged, compare against the version in HEAD.
        if node.staged then
            rev = "HEAD"
        end

        -- if not staged, compare against current version.
        git.show_file(rev, node.path, function(file)
            if file == nil then
                return
            end
            local dbuff = diff_buf.new()
            dbuff.setup()
            local o = { listed = false, scratch = true, modifiable = false }
            dbuff.write_lines(file, "a", o)
            dbuff.open_buffer(node.path, "b")
            dbuff.diff()

            vim.api.nvim_set_current_win(self.win)
        end)
    end

    function self.toggle_view()
        if self.view == "list" then
            self.view = "tree"
            self.event_handler()
        else
            self.view = "list"
            self.event_handler()
        end
    end

    function self.get_commands()
        local log = self.logger.logger_from(nil, "Component.get_commands")
        return commands.new(self).get()
    end

    vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold" },
        { callback = self.event_handler })

    return self
end

return ChangesComponent
