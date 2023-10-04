local Workspace = {}

-- Given a @Workspace, determine if nvim-ide is currently opened to it.
function Workspace.is_current_ws(ws)
	if ws.tab == vim.api.nvim_get_current_tabpage() then
		return true
	end
	return false
end

return Workspace
