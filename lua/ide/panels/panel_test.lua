local panel = require('ide.panels.panel')
local component = require('ide.panels.component')

local M = {}

local TestComponent_t = component.Component_i:new()

function TestComponent_t:new(name)
    local t = component.Component_i:new(name)
    setmetatable(t, self)
    self.__index = self
    return t
end

function TestComponent_t:require_buf_create()
    local buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"test component: " .. self.name})
    return buf
end

function TestComponent_t:post_win_create()
end

function M.test()
    -- M.test_duplicate_panel()
    M.test_components()
end

function M.test_duplicate_panel()
    local ok, err = panel.Panel_t:new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_TOP)
    if not ok then
        assert(false, 'expected panel creation to succeed: ' .. err)
    end

    if pcall(function() panel.Panel_t:new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_TOP) end) then
        assert(false, 'expected duplicate panel creation to fail')
    end
end

function M.test_components()
    local tc = TestComponent_t:new("test_component_1")
    local p, err = panel.Panel_t:new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_TOP)
    if not p then
        assert(false, 'expected panel creation to succeed: ' .. err)
    end
    p:register_component(tc)
    p:open_panel()
end

return M
