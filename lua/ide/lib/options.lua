local Options = {}

function Options.merge(default, provided)
	if provided == nil then
		provided = {}
	end
	if default == nil then
		default = {}
	end
	return vim.tbl_deep_extend("force", default, provided)
end

return Options
