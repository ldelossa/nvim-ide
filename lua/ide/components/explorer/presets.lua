local Presets = {}

Presets.default = {
	expand = "zo",
	collapse = "zc",
	collapse_all = "zM",
	edit = "<CR>",
	edit_split = "s",
	edit_vsplit = "v",
	edit_tab = "t",
	hide = "<C-[>",
	close = "X",
	new_file = "n",
	delete_file = "D",
	new_dir = "d",
	rename_file = "r",
	move_file = "m",
	copy_file = "p",
	select_file = "<Space>",
	deselect_file = "<Space><Space>",
	change_dir = "cd",
	up_dir = "..",
	file_details = "i",
	toggle_exec_perm = "*",
	maximize = "+",
	minimize = "-",
}

Presets.nvim_tree = vim.tbl_deep_extend("keep", Presets.default, {
	-- new_file can be used to create direcotries
	-- by just ending with a `/`, like in nvim_tree
	new_dir = "<NOP>",
	new_file = "a",
	hide = "<NOP>",
	delete_file = "d",
	edit_split = "<C-x>",
	edit_vsplit = "<C-v>",
	edit_tab = "<C-t>",
	collapse_all = "W",
})

return Presets
