local M = {}

-- Component Interface
--
-- Component_i is an interface of a Component_t. 
-- A Component is a UI element, implemented by another plugin, that is displayed
-- in a Panel_t.
--
-- A plugin author who wishes to register a Component_t into a Panel_t must derive
-- their own Component_t and implement the asserted methods defined below.
M.Component_i = {
    -- a unique name for this component.
    name = "",
    -- the component's panel window id.
    win = nil,
    -- the component's buffer containing the components UI.
    buf = nil,
    -- whether the component is hidden from the Panel_t.
    hidden = nil,
    -- component specific state useful for the component author.
    state = {}
}

-- The constructor for a new Component_t.
--
-- Plugin authors are responsible for implementing a Component_t
function M.Component_i:new(name)
    local t = {}
    setmetatable(t, self)
    self.__index = self
    assert(name ~= nil or name ~= "", "Must construct a Component_t with a valid name.")
    self.name = name
    return t
end

-- A method invoked with the Panel_t wants to display the implemented Component_t's
-- UI buffer.
--
-- The Component_t must return a buffer ID with the component's UI rendered within
-- it.
--
-- The Component is free to perform any plugin related tasks required before its
-- window is displayed in the panel during this method.
--
-- @return: buffer id
function M.Component_i:request_buf_create()
    assert(true, 'Component must implement pre_win_create method')
end

-- A method invoked just after the Panel_t displays the registered Component_t.
--
-- When this method is invoked Neovim's current window will be the Component's 
-- window within the Panel_t.
--
-- Any per-window configurations can be applied on this hook.
function M.Component_i:post_win_create()
    assert(true, 'Component must implement post_win_create method')
end

-- Determines if this Component_t is currently displayed inside a Panel_t
function M.Component_i:is_displayed()
    if self.win == nil then
        return false
    end
    for _, w in ipairs(vim.api.nvim_list_wins()) do
        if w == self.win then
            if vim.api.nvim_win_is_valid(w) then
                return true
            end
        end
    end
    return false
end

-- Determines if this Component_t is valid. 
--
-- Validity checks can be implemented by the implementor.
-- The default implementation simply checks of self.buf is valid.
function M.Component_i:is_valid()
    return self.buf ~= nil and vim.api.nvim_buf_is_valid(self.buf)
end

-- Set the component's win as the current window.
function M.Component_i:focus()
    if self.win == nil or (not vim.api.nvim_win_is_valid(self.win)) then
        return
    end
    vim.api.nvim_set_current_win(self.win)
end

-- Returns whether the component is hidden in the panel.
function M.Component_i:is_hidden()
    return self.hidden
end

return M
