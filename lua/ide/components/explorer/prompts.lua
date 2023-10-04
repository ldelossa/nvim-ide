local Prompts = {}

-- A prompt which asks the user if they want to overwrite the file located at
-- @path.
--
-- @path - string, the path which should be either renamed or overwritten.
-- @file_op - function(path, overwrite), an abstracted file operation where
--            `path` is the file path being operated on and `overwrite` is whether
--            the operation is performed despite `path` existing.
function Prompts.should_overwrite(path, file_op)
	local file = vim.fn.fnamemodify(path, ":t")
	vim.ui.input({
		prompt = string.format("%s exists, overwrite or rename (leave blank to cancel): ", file),
		default = file,
	}, function(input)
		if input == nil or input == "" then
			-- just return, no input means cancel.
			return
		end
		if input == file then
			-- received the same input as prompt, indicates perform the
			-- overwrite.
			file_op(path, true)
			return
		end
		-- input is new, rewrite path and call file_op
		local basepath = vim.fn.fnamemodify(path, ":h")
		local to = basepath .. "/" .. input
		file_op(to, false)
	end)
end

-- A prompt which asks the user if they want to rename the file located at
-- @path.
--
-- Overwriting cannot happen here, and thus only new input is allowed.
--
-- @path - string, the path which should be either renamed or overwritten.
-- @file_op - function(path), an abstracted file operation where
--            `path` is the file path being operated on.
function Prompts.must_rename(path, file_op)
	local file = vim.fn.fnamemodify(path, ":t")
	vim.ui.input({
		prompt = string.format("%s exists, must rename or cancel (leave input blank to cancel): ", file),
		default = file,
	}, function(input)
		if input == nil or input == "" then
			-- just return, no input means cancel.
			return
		end
		-- received the same input, prompt again
		if input == file then
			Prompts.must_rename(path, file_op)
			return
		end
		-- input is new, rewrite path and call file_op
		local basepath = vim.fn.fnamemodify(path, ":h")
		local to = basepath .. "/" .. input
		file_op(to)
	end)
end

function Prompts.get_filename(callback)
	vim.ui.input({
		prompt = string.format("enter filename: "),
	}, function(input)
		if input == nil or input == "" then
			return
		end
		callback(input)
	end)
end

function Prompts.get_dirname(callback)
	vim.ui.input({
		prompt = string.format("enter filename: "),
	}, function(input)
		if input == nil or input == "" then
			return
		end
		callback(input)
	end)
end

function Prompts.get_file_rename(original_path, callback)
	vim.ui.input({
		prompt = string.format("rename file to: "),
		default = vim.fn.fnamemodify(original_path, ":t"),
	}, function(input)
		callback(input)
	end)
end

function Prompts.should_delete(path, callback)
	vim.ui.input({
		prompt = string.format("delete %s? (Y/n): ", vim.fn.fnamemodify(path, ":t")),
	}, function(input)
		if input:lower() ~= "y" then
			return
		end
		callback()
	end)
end

return Prompts
