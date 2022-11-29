local logger = require('ide.logger.logger')
local libwin = require('ide.lib.win')

local ComponentTracker = {}

-- A ComponentTracker is responsible for listening to autocommand events and
-- updating stateful properties of a @Component within a @Panel and storing
-- these updates in the @Component's state field.
ComponentTracker.new = function(panel)
    assert(panel ~= nil, "Cannot construct a ComponentTracker without a panel.")
    local self = {
        -- the @Panel this component tracker is tracking components for.
        panel = panel,
        -- a table of created autocommands for components being tracked.
        active_autocmds = {},
    }

    local function find_component_by_win(win)
        local found = nil
        for _, c in ipairs(panel.components) do
            if c.win == win then
                found = c
            end
        end
        return found
    end

    -- an autocmd which updates the window dimensions of a component.
    function self.on_win_scroll_event(args, component)
        local log = logger.new("panels", "ComponentTracker.on_win_scrolled_event")
        local win = nil

        -- we will allow the passing in of the component, this is helpful on 
        -- a call to self.refresh() since we want to populate component state 
        -- sometimes before the autocmds fire
        if args == nil then
            if component ~= nil and component.win ~= nil then
                win = component.win
            else
                return
            end
        else
            win = tonumber(args.match)
        end

        log.debug("handling win scrolled event for %s in ws %d", self.panel.position, self.panel.tab)
        local c = find_component_by_win(win)
        if c == nil then
            log.debug("nil component for win %d, returning", win)
            return
        end

        log.debug("getting dimensions for: panel %s ws %d component %s", self.panel.position, self.panel.tab, c.name)
        local dimensions = {
            height = vim.api.nvim_win_get_height(win),
            width = vim.api.nvim_win_get_width(win)
        }
        c.state["dimensions"] = dimensions

        -- set the major size of the panel to be remembered on toggle
        if self.panel.position == "top" or self.panel.position == "bottom" then
            self.panel.size = c.state["dimensions"].height
        else
            self.panel.size = c.state["dimensions"].width
        end

        -- update all other open components, since a subsequent winscrolled event
        -- is not fired when an adjacent window is moved.
        for _, cc in ipairs(self.panel.components) do
            if cc.is_displayed() then
                local h = vim.api.nvim_win_get_height(cc.win)
                local w = vim.api.nvim_win_get_width(cc.win)
                cc.state["dimensions"].height = h
                cc.state["dimensions"].width = w
            end
        end

        log.debug("wrote dimensions update to component state: dimensions [%d,%d]", dimensions.height, dimensions.width)
    end

    -- an autocmd which records the last cursor position along with a restore
    -- function.
    function self.on_cursor_moved(_, component)
        local log = logger.new("panels", "ComponentTracker.on_cursor_moved")
        local win = vim.api.nvim_get_current_win()

        -- we will allow the passing in of the component, this is helpful on 
        -- a call to self.refresh() since we want to populate component state 
        -- sometimes before the autocmds fire
        if component ~= nil and component.win ~= nil then
            win = component.win
        end

        log.debug("handling cursor moved event for %s in ws %d", self.panel.position, self.panel.tab)
        local c = find_component_by_win(win)
        if c == nil then
            log.debug("nil component for win %d, returning", win)
            return
        end

        log.debug("getting cursor for: panel %s ws %d component %s", self.panel.position, self.panel.tab, c.name)
        local cursor = libwin.get_cursor(win)
        c.state["cursor"] = {
            cursor = cursor,
            -- restore the *current* value of win if possible, this occurs when
            -- the component is toggled closed and open.
            restore = function()
                if not libwin.win_is_valid(c.win) then
                    return
                end
                libwin.safe_cursor_restore(c.win, c.state["cursor"].cursor)
            end
        }
        log.debug("wrote cursor update to component state: cursor [%d,%d]", cursor[1], cursor[2])
    end

    -- used to register autocommands on panel changes, like registering a new
    -- component.
    function self.refresh()
        local log = logger.new("panels", "ComponentTracker.refresh")

        log.debug("refreshing component tracker for %s panel on workspace %d", self.panel.position, self.panel.tab)
        for _, aucmd in ipairs(self.active_autocmds) do
                vim.api.nvim_del_autocmd(aucmd.id)
        end
        self.active_autocmds = (function() return {} end)()
        for _, c in ipairs(panel.components) do
                table.insert(self.active_autocmds, {
                    id = vim.api.nvim_create_autocmd(
                        {"WinScrolled"},
                        {
                            pattern = {tostring(c.win)},
                            callback = self.on_win_scroll_event
                        }
                    ),
                    component = c
                })
        end
        table.insert(self.active_autocmds, {
            id = vim.api.nvim_create_autocmd(
                {"CursorMoved"},
                {
                    pattern = "component://*",
                    callback = self.on_cursor_moved
                }
            ),
        })
        for _, c in ipairs(self.panel.components) do
            if c.state["cursor"] == nil then
                self.on_cursor_moved(nil, c)
            end
            if c.state["dimensions"] == nil then
                self.on_win_scroll_event(nil, c)
            end
        end
    end

    return self
end

return ComponentTracker
