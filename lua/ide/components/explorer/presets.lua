local Presets = {}

Presets.default = {
	change_dir = "cd",
	close = "X",
	collapse = "zc",
	collapse_all = "zM",
	copy_file = "p",
	delete_file = "D",
	deselect_file = "<Space><Space>",
	edit = "<CR>",
	edit_split = "s",
	edit_tab = "t",
	edit_vsplit = "v",
	expand = "zo",
	file_details = "i",
	help = "?",
	hide = "H",
	maximize = "+",
	minimize = "-",
	move_file = "m",
	new_dir = "d",
	new_file = "n",
	rename_file = "r",
	select_file = "<Space>",
	toggle_exec_perm = "*",
	up_dir = "..",
}

Presets.nvim_tree = vim.tbl_deep_extend("force", Presets.default, {
	-- new_file can be used to create direcotries
	-- by just ending with a `/`, like in nvim_tree
	collapse_all = "W",
	delete_file = "d",
	edit_split = "<C-x>",
	edit_tab = "<C-t>",
	edit_vsplit = "<C-v>",
	hide = "<NOP>",
	new_dir = "<NOP>",
	new_file = "a",
})

return Presets
