local base     = require('ide.panels.component')
local tree     = require('ide.trees.tree')
local filenode = require('ide.components.explorer.filenode')
local commands = require('ide.components.explorer.commands')
local libwin   = require('ide.lib.win')
local libbuf   = require('ide.lib.buf')
local logger   = require('ide.logger.logger')
local prompts  = require('ide.components.explorer.prompts')
local presets  = require('ide.components.explorer.presets')
local icons = require('ide.icons')

local ExplorerComponent = {}

local config_prototype = {
    -- prefer sorting directories above normal files
    list_directories_first = false,
    -- show file permissions as virtual text on the right hand side.
    show_file_permissions = true,
    -- open the file on create in an editor window.
    edit_on_create = true,
    -- default component height
    default_height = nil,
    -- disable all keymaps for the Explorer component.
    disabled_keymaps = false,
    keymaps = presets.default,
}

-- ExplorerComponent is a derived @Component implementing a file explorer.
-- Must implement:
--  @Component.open
--  @Component.post_win_create
--  @Component.close
--  @Component.get_commands
ExplorerComponent.new = function(name, config)
    -- extends 'ide.panels.Component' fields.
    local self = base.new(name)
    -- a @Tree containing files and directories of the current workspace.
    self.tree = nil
    -- a list of selected nodes, if a selection exists then the next method
    -- invoked (mv, rename, cp, etc..) will be invoked for each node.
    self.selected = {}
    -- a logger that will be used across this class and its base class methods.
    self.logger = logger.new("explorer")
    -- holds fs_event_t watchers for currently expanded dir file nodes.
    -- this is a table where the keys are Filenode.key and the values are
    -- libuv's fs_event_t types.
    --
    -- when a dir fnode is expanded, its visible in the UI, so we register a watcher
    -- on it, and the dir fnode will be refreshed on event.
    --
    -- when the dir fnode is collapsed the fs_event_t is stopped and unregistered
    -- from this table.
    --
    -- when a "collapse all" is done, all fs_event_t's are stopped and unregistered
    -- from this table.
    self.fsevents = {}

    -- seup config, use default and merge in user config if not nil
    self.config = vim.deepcopy(config_prototype)
    if config ~= nil then
        self.config = vim.tbl_deep_extend("force", config_prototype, config)
    end

    local function setup_buffer()
        local log = self.logger.logger_from(nil, "Component._setup_buffer")

        local buf = vim.api.nvim_create_buf(false, true)
        local cur_tab = vim.api.nvim_get_current_tabpage()
        vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
        vim.api.nvim_buf_set_option(buf, 'filetype', 'filetree')
        vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        vim.api.nvim_buf_set_option(buf, 'swapfile', false)
        vim.api.nvim_buf_set_option(buf, 'textwidth', 0)
        vim.api.nvim_buf_set_option(buf, 'wrapmargin', 0)

        if not self.config.disable_keymaps then
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.expand, "",
                { silent = true, callback = self.expand })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.collapse, "", { silent = true,
                callback = self.collapse })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.collapse_all, "",
                { silent = true, callback = self.collapse_all })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.edit, "",
                { silent = true, callback = function() self.open_filenode({ fargs = {} }) end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.edit_split, "",
                { silent = true, callback = function() self.open_filenode({ fargs = { "split" } }) end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.edit_vsplit, "",
                { silent = true, callback = function() self.open_filenode({ fargs = { "vsplit" } }) end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.edit_tab, "",
                { silent = true, callback = function() self.open_filenode({ fargs = { "tab" } }) end })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.hide, "", { silent = true, callback = self.hide })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.new_file, "",
                { silent = true, callback = self.touch })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.delete_file, "",
                { silent = true, callback = self.rm })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.new_dir, "",
                { silent = true, callback = self.mkdir })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.rename_file, "",
                { silent = true, callback = self.rename })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.move_file, "",
                { silent = true, callback = self.mv })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.copy_file, "",
                { silent = true, callback = self.cp })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.select_file, "",
                { silent = true, callback = self.select })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.deselect_file, "",
                { silent = true, callback = self.unselect })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.maximize, "", { silent = true,
                callback = self.maximize })
            vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.minimize, "", { silent = true,
                callback = self.minimize })
        end

        return buf
    end

    -- (re)init the Explorer component, used on first construction and also when
    -- 'DirChanged event is fired.'
    function self.init()
        local log = self.logger.logger_from(nil, "Component.init")

        -- we can create the initial root tree at creation time, it will be marshalled
        -- and displayed into a buffer when the associated @Panel calls self.open()
        local cwd = vim.fn.getcwd()
        log.debug("initializing explorer: [workspace] %d [root] %s", vim.api.nvim_get_current_tabpage(), cwd)

        local kind = vim.fn.getftype(cwd)
        local perms = vim.fn.getfperm(cwd)
        local root = filenode.new(
            cwd,
            kind,
            perms,
            0,
            {
                list_directories_first = self.config.list_directories_first,
                show_file_permissions = self.config.show_file_permissions,
            }
        )
        self.tree = tree.new("file")
        self.tree.add_node(root, {})
        root.expand()

        self.register_fsevent(root)

        -- create a buffer if we don't have one.
        if self.buf == nil then
            -- log.debug("buffer does not exist, creating.", vim.api.nvim_get_current_tabpage())
            self.buf = setup_buffer()
        end
        log.debug("using buffer %d", self.buf)

        -- give our filenode tree a buffer
        self.tree.set_buffer(self.buf)
    end

    -- implements @Component interface
    function self.open()
        local log = self.logger.logger_from(nil, "Component.open")
        log.debug("Explorer component opening, workspace %s", vim.api.nvim_get_current_tabpage())

        -- if we've never setup a buffer it means we haven't initialized at all.
        if self.buf == nil then
            self.init()
        end

        -- do an initial marshal into the buffer
        self.tree.marshal({ virt_text_pos = 'right_align' })

        -- return the buffer for display
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
        -- set highlights for global icon theme
        icons.global_icon_set.set_win_highlights()
        if self.tree.root ~= nil then
            local title = vim.fn.fnamemodify(self.tree.root.path, ":t")
            libwin.set_winbar_title(0, title)
        end
    end

    -- implements @Component interface
    function self.get_commands()
        local log = self.logger.logger_from(nil, "Component.get_commands")
        return commands.new(self).get()
    end

    function self.register_fsevent(fnode)
        local log = self.logger.logger_from(nil, "Component.register_fsevent")
        if self.fsevents[fnode.key] ~= nil then
            self.unregister_fsevent(fnode)
        end
        log.debug("Registered fs_event watcher for %s", fnode.path)
        self.fsevents[fnode.key] = vim.loop.new_fs_event()
        self.fsevents[fnode.key]:start(fnode.path, {}, vim.schedule_wrap(function(err, filename, status)
            local log = self.logger.logger_from(nil, string.format("fs_event_%s", fnode.key))
            log.debug('received event: [err] %s [filename] %s [status] %s',
                vim.inspect(err),
                vim.inspect(filename),
                vim.inspect(status)
            )
            self.expand(nil, fnode)
        end))
    end

    function self.unregister_fsevent(fnode)
        local log = self.logger.logger_from(nil, "Component.unregister_fsevent")
        if self.fsevents[fnode.key] ~= nil then
            self.fsevents[fnode.key]:stop()
            self.fsevents[fnode.key] = nil
            log.debug("Unregistered fs_event watcher for %s", fnode.path)
        end
    end

    function self.unregister_all_fsevents()
        local log = self.logger.logger_from(nil, "Component.unregister_all_fsevents")
        for key, timer in pairs(self.fsevents) do
            timer:stop()
            self.fsevents[key] = nil
        end
        log.debug("Unregistered all fs_event watchers")
    end

    -- implements optional @Component interface
    -- Expand the @FileNode at the current cursor location
    --
    -- @args - @table, user command table as described in ":h nvim_create_user_command()"
    -- @fnode - @FileNode, an override which expands the given @FileNode, ignoring the
    --          node under the current position.
    function self.expand(args, fnode)
        local log = self.logger.logger_from(nil, "Component.expand")
        if not libwin.win_is_valid(self.win) then
            return
        end
        if fnode == nil then
            fnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
            if fnode == nil then
                return
            end
        end
        if fnode.kind ~= "dir" then
            return
        end
        fnode.expand()
        self.register_fsevent(fnode)
        self.tree.marshal({ virt_text_pos = 'right_align' })
        self.state["cursor"].restore()
    end

    -- Collapse the @FileNode at the current cursor location
    --
    -- @args - @table, user command table as described in ":h nvim_create_user_command()"
    -- @fnode - @FileNode, an override which collapses the given @FileNode, ignoring the
    --          node under the current position.
    function self.collapse(args, fnode)
        log = self.logger.logger_from(nil, "Component.expand")
        if not libwin.win_is_valid(self.win) then
            return
        end
        if fnode == nil then
            fnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
            if fnode == nil then
                return
            end
        end
        if fnode.kind ~= "dir" then
            return
        end
        self.tree.collapse_subtree(fnode)
        self.tree.marshal({ virt_text_pos = 'right_align' })
        self.state["cursor"].restore()
    end

    function self.collapse_all(args)
        local log = self.logger.logger_from(nil, "Component.expand")
        if not libwin.win_is_valid(self.win) then
            return
        end
        self.tree.collapse_subtree(self.tree.root)
        self.unregister_all_fsevents()
        self.tree.marshal({ virt_text_pos = 'right_align' })
        self.state["cursor"].restore()
    end

    -- Create a file at the current cursor location.
    --
    -- @args - @table, user command table as described in ":h nvim_create_user_command()"
    function self.touch(args)
        local log = self.logger.logger_from(nil, "Component.touch")
        if not libwin.win_is_valid(self.win) then
            return
        end
        local fnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if fnode == nil then
            return
        end
        if fnode.kind ~= "dir" then
            fnode = fnode.parent
        end
        prompts.get_filename(function(input)
            fnode.touch(input)
            self.tree.marshal({ virt_text_pos = 'right_align' })
            self.state["cursor"].restore()
            local path = fnode.path .. "/" .. input
            -- only edit if the created path is a file, not a directory
            if self.config.edit_on_create and not vim.endswith(input, '/') then
                vim.api.nvim_set_current_win(self.workspace.get_win())
                vim.cmd("edit " .. path)
            end
        end)
    end

    -- Create a directory at the current cursor location.
    --
    -- @args - @table, user command table as described in ":h nvim_create_user_command()"
    function self.mkdir(args)
        local log = self.logger.logger_from(nil, "Component.mkdir")
        if not libwin.win_is_valid(self.win) then
            return
        end
        local fnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if fnode == nil then
            return
        end
        if fnode.kind ~= "dir" then
            fnode = fnode.parent
        end
        prompts.get_filename(function(input)
            fnode.mkdir(input)
            self.tree.marshal({ virt_text_pos = 'right_align' })
            self.state["cursor"].restore()
        end)
    end

    local function _iterate_selected(callback)
        for _, fnode in ipairs(self.selected) do
            -- do a search and compare depths, the list of components could be stale.
            local found = self.tree.search_key(fnode.key)
            if found == nil then
                goto continue
            end
            if found.depth ~= fnode.depth then
                goto continue
            end
            callback(found)
            found.unselect()
            ::continue::
        end
        self.selected = (function() return {} end)()
    end

    -- Rename the file at the current cursor.
    --
    -- @args - @table, user command table as described in ":h nvim_create_user_command()"
    function self.rename(args)
        local log = self.logger.logger_from(nil, "Component.rename")

        if not libwin.win_is_valid(self.win) then
            return
        end

        local function rename(fnode)
            if fnode == nil then
                return
            end
            prompts.get_file_rename(
                fnode.path,
                function(input)
                    fnode.rename(input)
                end)
        end

        if #self.selected > 0 then
            _iterate_selected(rename)
        else
            local fnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
            rename(fnode)
        end
        self.tree.marshal({ virt_text_pos = 'right_align' })
        self.state["cursor"].restore()
    end

    -- Remove the file at the current cursor.
    --
    -- @args - @table, user command table as described in ":h nvim_create_user_command()"
    function self.rm(args)
        local log = self.logger.logger_from(nil, "Component.expand")

        if not libwin.win_is_valid(self.win) then
            return
        end

        local function rm(fnode)
            if fnode == nil then
                return
            end
            prompts.should_delete(
                fnode.path,
                function()
                    fnode.rm()
                end)

        end

        if #self.selected > 0 then
            _iterate_selected(rm)
        else
            local fnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
            rm(fnode)
            -- cleanup if we have a dir watcher
            if fnode.kind == "dir" then
                self.unregister_fsevent(fnode)
            end
        end
        self.tree.marshal({ virt_text_pos = 'right_align' })
        self.state["cursor"].restore()
    end

    -- Copy any currently selected nodes to the directory at the current cursor
    --
    -- @args - @table, user command table as described in ":h nvim_create_user_command()"
    function self.cp(args)
        local fnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if fnode.kind ~= "dir" then
            fnode = fnode.parent
        end
        _iterate_selected(function(fnode2)
            fnode2.cp(fnode)
        end)
        fnode.expand()
        self.tree.marshal({ virt_text_pos = 'right_align' })
        self.state["cursor"].restore()
    end

    -- Move any currently selected nodes to the directory at the current cursor
    --
    -- @args - @table, user command table as described in ":h nvim_create_user_command()"
    function self.mv(args)
        local fnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if fnode.kind ~= "dir" then
            fnode = fnode.parent
        end
        _iterate_selected(function(fnode2)
            fnode2.mv(fnode)
        end)
        fnode.expand()
        self.tree.marshal({ virt_text_pos = 'right_align' })
        self.state["cursor"].restore()
    end

    -- Select the file at the current cursor.
    --
    -- @args - @table, user command table as described in ":h nvim_create_user_command()"
    function self.select(args)
        local log = self.logger.logger_from(nil, "Component.select")
        if not libwin.win_is_valid(self.win) then
            return
        end
        local fnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if fnode == nil or fnode.depth == 0 then
            return
        end
        fnode.select()
        table.insert(self.selected, fnode)
        self.tree.marshal({ virt_text_pos = 'right_align' })
        self.state["cursor"].restore()
    end

    -- Unselect the file at the current cursor.
    --
    -- @args - @table, user command table as described in ":h nvim_create_user_command()"
    function self.unselect(args)
        log = self.logger.logger_from(nil, "Component.unselect")
        if not libwin.win_is_valid(self.win) then
            return
        end
        local fnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if fnode == nil or fnode.depth == 0 then
            return
        end
        fnode.unselect()

        local remaining = {}
        for _, s in ipairs(self.selected) do
            if s.key ~= fnode.key then
                table.insert(remaining, s)
            end
        end

        self.selected = (function() return {} end)()
        self.selected = remaining
        self.tree.marshal({ virt_text_pos = 'right_align' })
        self.state["cursor"].restore()
    end

    -- Open the file under the cursor for editing.
    --
    -- @args - @table, user command table as described in ":h nvim_create_user_command()"
    function self.open_filenode(args)
        local log = self.logger.logger_from(nil, "Component.open_filenode")

        local split = false
        local vsplit = false
        local tab = false
        for _, arg in ipairs(args.fargs) do
            if arg == "split" then
                split = true
            end
            if arg == "vsplit" then
                vsplit = true
            end
            if arg == "tab" then
                tab = true
            end
        end

        local fnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
        if fnode == nil then
            return
        end

        -- if fnode is a dir, we can open or close it instead of opening for edit.
        if fnode.kind == "dir" then
            if fnode.expanded then
                self.collapse(nil, fnode)
            else
                self.expand(nil, fnode)
            end
            return
        end

        if self.workspace == nil then
            log.error("component has a nil workspace, can't open filenode %s", fnode.path)
        end
        local win = self.workspace.get_win()
        vim.api.nvim_set_current_win(win)

        if split then
            vim.cmd("split")
        elseif vsplit then
            vim.cmd("vsplit")
        elseif tab then
            vim.cmd("tabnew")
        end

        vim.cmd("edit " .. vim.fn.fnamemodify(fnode.path, ":."))
    end

    function self.expand_to_file(path)

        local dest = vim.fn.fnamemodify(path, ":.")

        local function recursive_expand(root, path)
            -- ignore root node, we want to start searching at children.
            if root.depth == 0 then
                for _, child in ipairs(root.children) do
                    recursive_expand(child, path)
                end
                return
            end

            local current = vim.fn.fnamemodify(root.path, ":.")

            if vim.fn.match(dest, current) >= 0 then
                -- expanding will set a node's children to collapsed, so only do
                -- this if the node is not currently expanded, this allows the
                -- tree to keep existing open directories open but still snap to
                -- the currently opened file.
                if not root.expanded then
                    -- call self.expand so we setup an fs_event watcher
                    self.expand(nil, root)
                end

                -- we expanded to our destination, marshal the tree and set cursor.
                if current == dest then
                    if libwin.win_is_valid(self.win) then
                        self.tree.marshal({ virt_text_pos = 'right_align' })
                        vim.api.nvim_win_set_cursor(self.win, { root.line, 1 })
                        vim.api.nvim_buf_add_highlight(self.tree.buffer, -1, "CursorLine", root.line - 1, 0, -1)
                    end
                    return
                end

                -- not at destination yet, continue walking the tree.
                for _, child in ipairs(root.children) do
                    recursive_expand(child, path)
                end

            end
        end

        recursive_expand(self.tree.root, path)
    end

    function self.expand_to_file_aucmd(args)
        local log = self.logger.logger_from(nil, "Component.expand_to_file_aucmd")

        if not libbuf.is_regular_buffer(0) then
            log.debug("event was for a non file buffer, returning.")
            return
        end

        if self.workspace == nil then
            log.warning("no workspace set for component, returning.")
            return
        end

        local cur_tab = vim.api.nvim_get_current_tabpage()
        if self.workspace.tab ~= cur_tab then
            log.debug("event for tab %d does not pertain to us, workspace[%d]", cur_tab, self.workspace.tab)
            return
        end

        if libwin.is_component_win(0) then
            log.debug("event was for a component window, returning.")
            return
        end

        local buf_name = vim.api.nvim_buf_get_name(0)
        log.debug("expanding tree to current file %s", buf_name)
        self.expand_to_file(buf_name)
    end

    vim.api.nvim_create_autocmd({ "BufEnter" },
        { callback = self.expand_to_file_aucmd })

    vim.api.nvim_create_autocmd(
        { "DirChanged" },
        {
            callback = function(args)
                if not libbuf.is_regular_buffer(0) then
                    return
                end
                local ws = self.workspace.tab
                local cwd = vim.fn.getcwd(-1, ws)
                if (ws == vim.api.nvim_get_current_tabpage()) then
                    local lcwd = vim.fn.getcwd(0, 0)
                    if self.tree.root.path ~= lcwd then
                        self.init()
                        self.tree.marshal({ virt_text_pos = 'right_align' })
                    end
                    return
                end
                if self.tree.root.path ~= cwd then
                    self.init()
                    self.tree.marshal({ virt_text_pos = 'right_align' })
                end
            end
        }
    )

    return self
end

return ExplorerComponent
