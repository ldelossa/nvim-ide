Buf = {}

function Buf.buf_is_valid(buf)
    if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
        return true
    end
    return false
end

function Buf.is_component_buf(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.fn.match(name, "component://") >= 0 then
        return true
    end
    return false
end

function Buf.is_regular_buffer(buf)
    if not Buf.buf_is_valid(buf) then
        return false
    end
    -- only consider normal buffers with files loaded into them.
    if vim.api.nvim_buf_get_option(buf, "buftype") ~= "" then
        return false
    end
    return true
end

function Buf.truncate_buffer(buf)
    if Buf.buf_is_valid(buf) then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    end
end

function Buf.toggle_modifiable(buf)
    if Buf.buf_is_valid(buf) then
        vim.api.nvim_buf_set_option(buf, 'modifiable', true)
        return function()
            vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        end
    end
    return function() end
end

function Buf.has_lsp_clients(buf)
    if #vim.lsp.get_active_clients({bufnr=buf}) > 0 then
        return true
    end
    return false
end

function Buf.set_option_with_restore(buf, option, value)
    local cur = vim.api.nvim_buf_get_option(buf, option)
    vim.api.nvim_win_set_option(buf, value)
    return function()
        vim.api.nvim_win_set_option(buf, cur)
    end
end

function Buf.buf_exists_by_name(name)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
        if buf_name == name then
            return true, buf
        end
    end
    return false
end

function Buf.delete_buffer_by_name(name)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
        if buf_name == name then
            vim.api.nvim_buf_delete(buf, {force=true})
        end
    end
end

return Buf
