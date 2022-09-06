local M = {}

-- Panel_Registry_t is a registry of Panel_t instances which ensures only a single 
-- panel for each M.PANEL_POSITIONS can be created on a given tab.
M.Panel_Registry_t = {
    panels = {
        ['1'] = nil
    }
}

function M.Panel_Registry_t:new()
    local t = {}
    setmetatable(t, self)
    self.__index = self
    return t
end

function M.Panel_Registry_t:register(Panel_t)
    local panels = self.panels[Panel_t.tab]

    if panels == nil then
        self.panels[Panel_t.tab] = {Panel_t}
        return true
    end

    for _, p in ipairs(panels) do
        if p.position == Panel_t.position then
            return false, "duplicate panel at position " .. p.position
        end
    end
    table.insert(self.panels[Panel_t.tab], Panel_t)
    return true
end

-- A global Panel_Registry used on Panel_t construction.
M.Panel_Registry = M.Panel_Registry_t:new()

-- Panel Position Enum
M.PANEL_POS_TOP = "top"
M.PANEL_POS_LEFT = "left"
M.PANEL_POS_RIGHT = "right"
M.PANEL_POS_BOTTOM = "bottom"
M.PANEL_POSITIONS = {
    M.PANEL_POS_TOP, M.PANEL_POS_LEFT, M.PANEL_POS_RIGHT, M.PANEL_POS_BOTTOM
}

-- A Panel_t is a controlling container over several Component_i implementations,
-- acting a single window abstraction over multiple Component windows.
--
-- The Panel_t uses a desired state algorithm to determine which windows must be
-- opened and closed to achieve displaying the panel correctly.
M.Panel_t = {
    -- the tab which owns this panel
    tab = nil,
    -- the position where this panel will be displayed.
    position = "left",
    -- the initial size of the panel.
    size = 15,
    -- an array of registered Component_i implementations.
    components = {},
    -- the panel's current layout, an array of Component_i implementations.
    layout = {},
}

-- Constructs a new Panel_t type.
--
-- A Panel_t implements a panel of components which can be displayed on the
-- provided tab.
--
-- @tab - a valid tab id (required)
-- @position - a PANEL_POSITIONS enum value specifying where this panel will 
-- be displayed. (required)
-- @components - a list of Component_t types registered to this Panel_t.
-- (optional)
function M.Panel_t:new(tab, position, components)
        local t = {}
        setmetatable(t, self)
        self.__index = self

        assert(tab ~= nil, "cannot construct a panel without an associated tab")
        assert(vim.api.nvim_tabpage_is_valid(tab), "cannot construct a panel without an invalid tab")
        assert(position ~= nil, "cannot construct a panel without a position")
        for _, pos in ipairs(M.PANEL_POSITIONS) do
            if position == pos then
                self.position = position
            end
        end
        if components ~= nil and #components > 0 then
            self.components = components
        end
        self.tab = tab

        local ok, err = M.Panel_Registry:register(self)
        if not ok then
            assert(M.Panel_Registry:register(self), err)
        end

        return t
end

-- Register a new Component_i implementation into this Panel_t.
-- see ide/panels/component.lua for Component_i declaration.
function M.Panel_t:register_component(Component_t)
    table.insert(self.components, Component_t)
end

-- Determine if the Panel_t is opened. 
--
-- Since a Panel_t is an abstraction over several Component_t windows, this method
-- simply checks if all Component_t windows are invalid or nil.
function M.Panel_t:is_open()
    for _, c in ipairs(self.components) do
        if c.is_displayed() then
            return true
        end
    end
    return false
end

-- attach a registered Component_t to this Panel_t.
function M.Panel_t:_attach_component(Component_t)
    local panel_win = vim.api.nvim_get_current_win()
    local buf = Component_t:request_buf_create()
    vim.api.nvim_win_set_buf(buf)
    Component_t.win = panel_win
    Component_t.buf = buf
    Component_t:post_win_create()
    table.insert(self.layout, Component_t)
end

function M.Panel_t:close_panel()
    if not self:is_open() then
        return
    end
    for _, c in ipairs(self.layout) do
        if c:is_valid() then
            vim.api.nvim_win_close(c.win)
        end
    end
end

-- open this Panel_t, displaying all registered Component_t that are not hidden.
function M.Panel_t:open_panel()
    if self:is_open() then
        return
    end

    self.layout = (function() return {} end)()

    -- create a new split for our panel.
    if self.position == M.PANEL_POS_LEFT then
        vim.cmd("topleft vsplit")
        vim.cmd("vertical resize " ..
                    self.size)
    elseif self.position == M.PANEL_POS_RIGHT then
        vim.cmd("botright vsplit")
        vim.cmd("vertical resize " ..
                    self.size)
    elseif self.position == M.PANEL_POS_TOP then
        vim.cmd("topleft split")
        vim.cmd("resize " ..
                    self.size)
    elseif self.position == M.PANEL_POS_BOTTOM  then
        vim.cmd("botright split")
        vim.cmd("resize " ..
                    self.size)
    end

    -- place non-hidden components 
    for i, rc in ipairs(self.components) do
        if rc:is_hidden() then
            goto continue
        end

        self:_attach_component(rc)

        if i ~= #self.components then
            if self.position == M.PANEL_POS_LEFT then
                vim.cmd("below split")
            elseif self.position == M.PANEL_POS_RIGHT then
                vim.cmd("below split")
            elseif self.position == M.PANEL_POS_TOP then
                vim.cmd("vsplit")
            elseif self.position == M.PANEL_POS_TOP then
                vim.cmd("vsplit")
            end
        end
        ::continue::
    end
end

function M.Panel_t:open_component(name)
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
    if c:is_displayed() then
        c:focus()
        return
    end

    -- if the panel isn't opened, set the desired component hidden to false
    -- and open the panel, the component will be opened with other non-hidden ones.
    if not self:is_opened() then
        c.hidden = false
        self:open_panel()
        return
    end

    -- place ourselves inside first valid panel window
    for _, rc in ipairs(self.components) do
        if rc:is_valid() then
            rc:focus()
            break
        end
    end

end

return M
