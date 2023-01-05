local registry = require('ide.panels.panel_registry')
local libwin = require('ide.lib.win')
local logger = require('ide.logger.logger')

local Panel = {}

-- Panel Position Enum
Panel.PANEL_POS_TOP = "top"
Panel.PANEL_POS_LEFT = "left"
Panel.PANEL_POS_RIGHT = "right"
Panel.PANEL_POS_BOTTOM = "bottom"
Panel.PANEL_POSITIONS = {
    Panel.PANEL_POS_TOP, Panel.PANEL_POS_LEFT, Panel.PANEL_POS_RIGHT, Panel.PANEL_POS_BOTTOM
}

local bool_to_string = function(b)
    return b and "true" or "false"
end

local debug_winsize = false
local winsize_debug = function(log, msg)
    if not debug_winsize then
        return
    end

    local current = vim.api.nvim_get_current_win()
    for _, w in ipairs(vim.api.nvim_list_wins()) do
        local width = vim.api.nvim_win_get_width(w)
        local height = vim.api.nvim_win_get_height(w)
        local title = vim.api.nvim_win_get_option(w, "winbar")
        local fixwidth = vim.api.nvim_win_get_option(w, "winfixwidth")
        local fixheight = vim.api.nvim_win_get_option(w, "winfixheight")
        local is_current = w == current

        log.info(os.date("%c|") .. msg .. "|width=" .. width
            .. ", fixwidth=" .. bool_to_string(fixwidth)
            .. ", height=" .. height .. ", fixheight=" .. bool_to_string(fixheight)
            .. ", win=" .. w .. ", title=" .. title
            .. ", is_current=" .. bool_to_string(is_current)
        )
    end
end


-- Construct a new Panel for a given tab and position.
--
-- A Panel is an abstraction of a set of windows and buffers, each of which are
-- created by a registered Component.
--
-- A Panel can be displayed at the top, left, right, or bottom of a tabpage.
-- One panel for each position can be registered per-tab page.
Panel.new = function(tab, position, components)
    assert(tab ~= nil, "cannot construct a panel without an associated tab")
    assert(vim.api.nvim_tabpage_is_valid(tab), "cannot construct a panel without an invalid tab")
    local self = {
        -- the tab which owns this panel
        tab = nil,
        -- the position where this panel will be displayed.
        position = "left",
        -- the initial size of the panel.
        size = 30,
        -- an array of registered Component_i implementations.
        components = {},
        -- the panel's current layout, an array of Component_i implementations.
        layout = {},
        -- the workspace this panel is associated with.
        workspace = nil,
        -- whether the panel has been opened already
        has_opened_once = false,
        logger = logger.new("panel", nil)
    }
    self.tab = tab

    -- construction validation
    if components ~= nil and #components > 0 then
        self.components = components
        for _, comp in ipairs(components) do
            comp.panel = self
        end
    end

    function self.set_position(position, size)
        for _, pos in ipairs(Panel.PANEL_POSITIONS) do
            if position == pos then
                self.position = position
            end
        end

        self.size = size
    end


    -- Register a new Component_i implementation into this Panel_t.
    -- see ide/panels/component.lua for Component_i declaration.
    --
    -- @return - void
    function self.register_component(Component)
        Component.panel = self
        table.insert(self.components, Component)
    end

    -- Determine if the Panel is opened.
    --
    -- Since a Panel is an abstraction over several Component windows, this method
    -- simply checks if all Component windows are invalid or nil.
    --
    -- @return - void
    function self.is_open()
        for _, c in ipairs(self.components) do
            if c.is_displayed() then
                return true
            end
        end
        return false
    end

    -- Closes the panel by closing all current Component windows.
    --
    -- @return - void
    function self.close()
        if not self.is_open() then
            return
        end
        local log = self.logger.logger_from("panel=" .. self.position)

        winsize_debug(log, "before close")
        for _, c in ipairs(self.layout) do
            if c.is_valid() and c.is_displayed() then
                vim.api.nvim_win_close(c.win, true)
            end
        end
        winsize_debug(log, "after close")
    end

    local function _set_default_win_opts(pos, win, name)
        libwin.set_winbar_title(win, name)
        vim.api.nvim_win_set_option(win, 'number', false)
        vim.api.nvim_win_set_option(win, 'cursorline', true)
        vim.api.nvim_win_set_option(win, 'relativenumber', false)
        vim.api.nvim_win_set_option(win, 'signcolumn', 'no')
        vim.api.nvim_win_set_option(win, 'wrap', false)

        local winfixwidth = self.position == Panel.PANEL_POS_LEFT or self.position == Panel.PANEL_POS_RIGHT
        local winfixheight = not winfixwidth
        vim.api.nvim_win_set_option(win, "winfixwidth", winfixwidth)
        vim.api.nvim_win_set_option(win, "winfixheight", winfixheight)
        vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:NormalSB')
    end

    local function _set_default_buf_opts(buf, component)
        -- all component buffers will map "=" to the `Workspace Reset` command.
        -- see: https://github.com/ldelossa/nvim-ide/discussions/91
        vim.api.nvim_buf_set_keymap(buf, "n", "=", "",
            { silent = true, callback = self.workspace.equal_components })
        -- all component buffers will map "+" to the `{Component}Maximize` command.
        -- see: https://github.com/ldelossa/nvim-ide/discussions/91
        vim.api.nvim_buf_set_keymap(buf, "n", "+", "",
            { silent = true, callback = component.maximize })
        vim.api.nvim_buf_set_keymap(buf, "n", "-", "",
            { silent = true, callback = component.minimize })
    end

    local function _attach_component(Component)
        local panel_win = vim.api.nvim_get_current_win()

        local buf = Component.open()

        vim.api.nvim_win_set_buf(panel_win, buf)

        Component.win = panel_win
        Component.buf = buf

        vim.api.nvim_buf_set_name(buf, string.format("component://%s:%d:%d", Component.name, panel_win, self.tab))
        _set_default_buf_opts(buf, Component)

        -- the bottom tab requires the ability to change buffers,
        -- for example to switch between multiple terminals via the terminal
        -- browser component.
        if self.position ~= Panel.PANEL_POS_BOTTOM then
            -- "lock" the buf to the window with an autocmd
            vim.api.nvim_create_autocmd({ 'BufWinEnter' }, {
                callback = function()
                  local curwin = vim.api.nvim_get_current_win()
                    if curwin == panel_win then
                        local curbuf = vim.api.nvim_win_get_buf(curwin)
                        if curbuf ~= buf then
                            -- restore ide component to panel win
                            vim.api.nvim_win_set_buf(panel_win, buf)
                            -- put the new buffer in the next appropriate editor window
                            local last_win = self.workspace.get_win()
                            vim.api.nvim_win_set_buf(last_win, curbuf)
                            vim.api.nvim_set_current_win(last_win)
                        end
                    end
                end,
            })
        end

        -- restore previous cursor if applicable
        Component.state["cursor"].restore()

        _set_default_win_opts(self.position, panel_win, Component.name)

        table.insert(self.layout, Component)

        -- set size of window, use the last recorded dimensions if possible.
        local size = self.size
        local dimensions = nil
        if Component.state["dimensions"] ~= nil then
            dimensions = Component.state["dimensions"]
        end

        if self.position == Panel.PANEL_POS_LEFT then
            vim.cmd("vertical resize " ..
                size)
        elseif self.position == Panel.PANEL_POS_RIGHT then
            vim.cmd("vertical resize " ..
                size)
        elseif self.position == Panel.PANEL_POS_TOP then
            vim.cmd("resize " ..
                size)
        elseif self.position == Panel.PANEL_POS_BOTTOM then
            vim.cmd("resize " ..
                size)
        end

        -- component may want to edit new win options/settings so call their 
        -- callback.
        Component.post_win_create()
    end

    -- Opens the panel by displaying all registered Component windows that
    -- are not hidden.
    --
    -- @return void
    function self.open()
        if self.is_open() then
            return
        end

        -- if all components are hidden, don't open the panel at all.
        local continue = false
        for _, rc in ipairs(self.components) do
            if not rc.is_hidden() then
                continue = true
            end
        end
        if not continue then
            return
        end

        local log = self.logger.logger_from(nil, "panel.open=" .. self.position)
        winsize_debug(log, "starting open")

        local old_layout = vim.tbl_extend('keep', self.layout, {})

        -- if we are configuring a top or bottom panel, we want to split right
        -- for vsplits to preserve config's ordering.
        --
        -- provide a restore function to restore the original option, it will 
        -- no-op if this is not a top or bottom panel
        local restore = (function()
            if self.position == Panel.PANEL_POS_BOTTOM or
                self.position == Panel.PANEL_POS_TOP
            then
                local original = vim.o.splitright
                vim.o.splitright = true
                return function()
                    vim.o.splitright = original
                end
            end
            return function() end
        end)()

        local resize_func
        -- run all win creation commands with no autocmd, so they won't get
        -- tracked as visited windows in @Workspace.
        if self.position == Panel.PANEL_POS_LEFT then
            vim.cmd("noautocmd topleft vsplit")
            resize_func = vim.api.nvim_win_set_width
        elseif self.position == Panel.PANEL_POS_RIGHT then
            vim.cmd("noautocmd botright vsplit")
            resize_func = vim.api.nvim_win_set_width
        elseif self.position == Panel.PANEL_POS_TOP then
            vim.cmd("noautocmd topleft split")
            resize_func = vim.api.nvim_win_set_height
        elseif self.position == Panel.PANEL_POS_BOTTOM then
            vim.cmd("noautocmd botright split")
            resize_func = vim.api.nvim_win_set_height
        end
        winsize_debug(log, "after first split")

        local current = vim.api.nvim_get_current_win()
        resize_func(current, self.size)
        winsize_debug(log, "after first resize")

        -- place non-hidden components, we already have the sidebar window, so 
        -- only split after the first attached component.
        local attached = 1
        self.layout = {}
        for _, rc in ipairs(self.components) do
            if not rc.is_hidden() then
                if attached ~= 1 then
                    if self.position == Panel.PANEL_POS_LEFT then
                        vim.cmd("noautocmd below split")
                    elseif self.position == Panel.PANEL_POS_RIGHT then
                        vim.cmd("noautocmd below split")
                    elseif self.position == Panel.PANEL_POS_TOP then
                        vim.cmd("noautocmd vsplit")
                    elseif self.position == Panel.PANEL_POS_BOTTOM then
                        vim.cmd("noautocmd vsplit")
                    end
                end
                _attach_component(rc)
                -- equal things ot, so we don't run our of space splitting 
                -- smaller and smaller windows up.
                self.equal()
                attached = attached + 1
            end
        end

        winsize_debug(log, "before normalize_panel")
        self.workspace.normalize_panels(self.position)
        winsize_debug(log, "after normalize_panel")

        -- normalizing may change the height of the bottom window
        -- even when winfixheight is set to the bottom window
        resize_func(current, self.size)
        winsize_debug(log, "after 2nd resize")

        -- if the layout is exactly the same as previous, restore dimensions.
        local restore_dimensions = true
        for i, c in ipairs(old_layout) do
            if self.layout[i].name ~= c.name then
                restore_dimensions = false
            end
        end
        if restore_dimensions then
            for _, c in ipairs(self.layout) do
                if c.is_displayed() then
                    c.restore_dimensions()
                end
            end
        end

        restore()
        self.init_component_sizes()
        winsize_debug(log, "finishing open")
    end

    function self.restore_default_heights()
        for _, component in ipairs(self.components) do
            local default_height = vim.tbl_get(component, 'config', 'default_height')
            if default_height ~= nil then
                vim.defer_fn(function()
                    vim.api.nvim_win_set_height(component.win, default_height)
                end, 1)
            end
        end
    end

    function self.init_component_sizes()
        if self.has_opened_once then
            return
        end

        self.has_opened_once = true
        self.restore_default_heights()
    end

    -- Opens the panel and focuses the Component identified by `name`
    --
    -- @name    - the unique name of a registered component
    -- @return  - void
    function self.open_component(name)
        local c = nil

        for _, rc in ipairs(self.components) do
            if rc.name == name then
                c = rc
            end
        end
        -- not a registered component, return
        if c == nil then
            return
        end

        -- component is currently displayed, focus it and return.
        if c.is_displayed() then
            c.focus()
            return
        end

        -- if the panel isn't opened, set the desired component hidden to false
        -- and open the panel, the component will be opened with other non-hidden ones.
        if not self.is_open() then
            c.hide(false)
            self.open()
            return
        end

        -- place ourselves inside first valid panel window
        for _, rc in ipairs(self.components) do
            if rc.is_valid() then
                rc.focus()
                break
            end
        end

    end

    -- Hides a currently displayed Component. 
    --
    -- @name    - the unique name of a registered component
    -- @return  - void
    function self.hide_component(name)
        local c = nil

        for _, rc in ipairs(self.components) do
            if rc.name == name then
                c = rc
            end
        end

        -- not a registered component, return
        if c == nil then
            return
        end

        c.hide(true)

        -- remove from layout.
        local new_layout = {}
        for _, cc in ipairs(self.layout) do
            if cc.Name ~= name then
                table.insert(new_layout, cc)
            end
        end
        self.layout = new_layout
    end

    -- Returns an array of any registered components.
    --
    -- @return - @table, an array of @Component(s) registered to this panel.
    function self.get_components()
        return self.components
    end

    function self.set_workspace(Workspace)
        for _, c in ipairs(self.components) do
            c.workspace = Workspace
        end
        self.workspace = Workspace
    end

    function self.get_workspace(Workspace)
        return self.workspace
    end

    function self.reset_panel_dimensions()
        for _, c in ipairs(self.components) do
            c.restore_dimensions()
        end
    end

    function self.equal()
        if not self.is_open() then
            return
        end
        local restores = {}

        -- make all windows across vim fixed (unaffected by "=")
        for _, w in ipairs(vim.api.nvim_list_wins()) do
            table.insert(restores, 1, libwin.set_option_with_restore(w, "winfixwidth", true))
            table.insert(restores, 1, libwin.set_option_with_restore(w, "winfixheight", true))
        end

        -- set any of our open component windows to false.
        for _, c in ipairs(self.components) do
            if c.is_displayed() then
                if self.position == Panel.PANEL_POS_BOTTOM or self.position == Panel.PANEL_POS_TOP then
                    table.insert(restores, 1, libwin.set_option_with_restore(c.win, "winfixwidth", false))
                    table.insert(restores, 1, libwin.set_option_with_restore(c.win, "winfixheight", true))
                else
                    table.insert(restores, 1, libwin.set_option_with_restore(c.win, "winfixwidth", true))
                    table.insert(restores, 1, libwin.set_option_with_restore(c.win, "winfixheight", false))
                end
            end
        end

        vim.cmd("wincmd =")

        -- if user supplied default heights for components restore them
        self.restore_default_heights()

        -- restore all fixes to their original values
        for _, r in ipairs(restores) do
            r()
        end
    end

    return self
end

return Panel
