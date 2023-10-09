local tree = require("ide.trees.tree")
local libbuf = require("ide.lib.buf")
local libws = require("ide.lib.workspace")
local icons = require("ide.icons")
local bookmarknode = require("ide.components.bookmarks.bookmarknode")
local base64 = require("ide.lib.encoding.base64")

local Notebook = {}

Notebook.RECORD_SEP = "␞"
Notebook.GROUP_SEP = "␝"

local bookmarks_ns = vim.api.nvim_create_namespace("bookmarks-ns")

Notebook.new = function(buf, name, file, bookmarks_component)
	local self = {
		name = name,
		buf = buf,
		file = file,
		tree = tree.new("bookmarks"),
		bookmarks = nil,
		sync_aucmd = nil,
		write_aucmd = nil,
		component = bookmarks_component,
		tracking = {},
	}
	self.tree.set_buffer(buf)

	if vim.fn.glob(file) == "" then
		error("attempted to open notebook for non-existent notebook directory")
	end

	local function _get_bookmark_file_full(buf_name)
		local bookmark_file = base64.encode(buf_name)
		local bookmark_file_path = self.file .. "/" .. bookmark_file
		local full_path = vim.fn.fnamemodify(bookmark_file_path, ":p")
		return full_path
	end

	function _remove_extmark(node)
		if self.tracking[node.file] == nil then
			return
		end
		local tracked = {}
		for _, bm in ipairs(self.tracking[node.file]) do
			if bm.key == node.key then
				vim.api.nvim_buf_del_extmark(bm.mark[1], bm.mark[3], bm.mark[2])
				goto continue
			end
			table.insert(tracked, bm)
			::continue::
		end
		self.tracking[node.file] = (function()
			return {}
		end)()
		self.tracking[node.file] = tracked
	end

	local function _create_extmark(buf, bm)
		local mark = vim.api.nvim_buf_set_extmark(buf, bookmarks_ns, bm.start_line - 1, 0, {
			virt_text_pos = "right_align",
			virt_text = { { icons.global_icon_set.get_icon("Bookmark") .. " " .. bm.title, "Keyword" } },
			hl_mode = "combine",
		})
		bm.mark = { buf, mark, bookmarks_ns }
		if self.tracking[bm.file] == nil then
			self.tracking[bm.file] = {}
		end
		table.insert(self.tracking[bm.file], bm)
	end

	-- Loads bookmarks from a notebook directory.
	--
	-- A notebook directory organizes bookmarks in a per-buffer fashion.
	-- Thus, the notebook directory is read and each file is a particular
	-- buffer's bookmarks.
	--
	-- Each bookmark within a per-buffer bookmark file is then marshalled into
	-- a @BookmarkNode
	function self.load_bookmarks()
		local nodes = {}
		for _, bookmark_file in ipairs(vim.fn.readdir(self.file)) do
			local bookmark_path = self.file .. "/" .. bookmark_file
			local lines = vim.fn.readfile(bookmark_path)
			for _, l in ipairs(lines) do
				local bm = bookmarknode.unmarshal_text(l)
				table.insert(nodes, bm)
			end
		end
		local root = bookmarknode.new("root", 0, 0, name, "", 0)
		self.tree.add_node(root, nodes)
		self.tree.marshal({ no_guides = true })
	end

	-- Do an initial loading of bookmarks on creation.
	self.load_bookmarks()

	-- append a bookmark to the notebook file, this is done on create so the
	-- use doesn't need to save the first bookmark they create.
	function self.append_bookmark_file(buf_name, bm)
		buf_name = vim.fn.fnamemodify(buf_name, ":.")
		local l = bm.marshal_text()
		local bookmark_file = _get_bookmark_file_full(buf_name)
		vim.fn.writefile({ l }, bookmark_file, "a")
		bm.dirty = false
	end

	-- removes a bookmark in the bookmark file associated with buf_name by
	-- reading the file in, excluding the line at index 'i' and writing it back
	-- to disk.
	function self.remove_bookmark_file(buf_name, i)
		buf_name = vim.fn.fnamemodify(buf_name, ":.")
		local bookmark_file = _get_bookmark_file_full(buf_name)
		local lines = vim.fn.readfile(bookmark_file)

		if #lines < i then
			return
		end

		local new_lines = {}
		for ii, l in ipairs(lines) do
			if i ~= ii then
				table.insert(new_lines, l)
			end
		end

		vim.fn.writefile(new_lines, bookmark_file)
	end

	function self.create_bookmark()
		local buf = vim.api.nvim_get_current_buf()
		if not libbuf.is_regular_buffer(buf) then
			vim.notify("Can only create bookmarks on source code buffers.", vim.log.levels.Error, {
					title = "Bookmarks",
				})
			return
		end
		local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
		local cursor = vim.api.nvim_win_get_cursor(0)
		vim.ui.input({
			prompt = "Give bookmark a title: ",
		}, function(input)
			if input == nil or input == "" then
				return
			end
			local bm = bookmarknode.new(file, cursor[1], cursor[1], input)
			self.append_bookmark_file(vim.api.nvim_buf_get_name(buf), bm)
			bm.original_start_line = cursor[1]
			self.tree.add_node(self.tree.root, { bm }, { append = true })
			self.tree.marshal({ no_guides = true })
			_create_extmark(buf, bm)
		end)
	end

	-- Removes a bookmark from memory and, if written, from disk.
	function self.remove_bookmark(key)
		local new_children = {}
		local node = nil
		local index = nil
		for i, n in ipairs(self.tree.depth_table.table[1]) do
			if n.key ~= key then
				table.insert(new_children, n)
			else
				index = i
				node = n
			end
		end

		-- remove from disk
		self.remove_bookmark_file(node.file, index)

		-- remove from memory
		self.tree.root.children = (function()
			return {}
		end)()
		self.tree.add_node(self.tree.root, new_children)
		self.tree.marshal({ no_guides = true })
		_remove_extmark(node)
	end

	function self.close()
		if self.sync_aucmd ~= nil then
			vim.api.nvim_del_autocmd(self.sync_aucmd)
		end
	end

	-- Writes the bookmarks for a given buffer name (relative to root), to
	-- disk.
	--
	-- Bookmarks are organized by buffer such that saving a buffer persists any
	-- bookmarks created for the buffer.
	--
	-- This allows for bookmarks to move around and be tracked in-memory but
	-- their ultimate position only persisted to disk when the buffer is also
	-- written.
	function self.write_bookmarks(buf_name)
		local lines = {}
		buf_name = vim.fn.fnamemodify(buf_name, ":.")
		self.tree.walk_subtree(self.tree.root, function(bm)
			if bm.file == buf_name then
				local l = bm.marshal_text()
				table.insert(lines, l)
			end
			-- set dirty to false, it will be written to disk next.
			bm.dirty = false
			bm.original_start_line = bm.start_line
			return true
		end)
		local bookmark_file = _get_bookmark_file_full(buf_name)
		vim.fn.writefile({}, bookmark_file)
		vim.fn.writefile(lines, bookmark_file)
		self.tree.marshal({ no_guides = true })
	end

	-- For the given buffer name, update any in-memory bookmark positions and dirty
	-- field if they have moved.
	function _sync_moved_bookmarks(buf_name)
		if self.tracking[buf_name] == nil then
			return
		end

		for _, bm in ipairs(self.tracking[buf_name]) do
			local mark = vim.api.nvim_buf_get_extmark_by_id(bm.mark[1], bm.mark[3], bm.mark[2], {})
			if bm.original_start_line ~= nil then
				if (mark[1] + 1) ~= bm.original_start_line then
					bm.dirty = true
				else
					bm.dirty = false
				end
			end
			bm.start_line = mark[1] + 1
		end
	end

	function _sync_removed_bookmarks(buf_name)
		if self.tracking[buf_name] == nil then
			return
		end

		local tracked = {}
		for _, bm in ipairs(self.tracking[buf_name]) do
			local present = self.tree.search_key(bm.key)
			if present == nil then
				vim.api.nvim_buf_del_extmark(bm.mark[1], bm.mark[3], bm.mark[2])
				goto continue
			end
			table.insert(tracked, bm)
			::continue::
		end

		self.tracking[buf_name] = (function()
			return {}
		end)()
		self.tracking[buf_name] = tracked
	end

	function _sync_missing_bookmarks(buf, buf_name)
		if self.tracking[buf_name] == nil then
			self.tracking[buf_name] = {}
		end
		for _, bm in ipairs(self.tree.depth_table.table[1]) do
			if bm.file == buf_name and bm.mark == nil then
				_create_extmark(buf, bm)
			end
		end
	end

	-- internal function for performing a sync between in-memory bookmarks
	-- and an open buffer.
	function _buf_sync_bookmarks(buf, buf_name)
		if not libbuf.is_regular_buffer(buf) then
			return
		end

		if self.tree.depth_table.table[1] == nil then
			return
		end

		buf_name = vim.fn.fnamemodify(buf_name, ":.")

		_sync_moved_bookmarks(buf_name)

		_sync_removed_bookmarks(buf_name)

		_sync_missing_bookmarks(buf, buf_name)

		-- marshal any updated node positions.
		self.tree.marshal({ no_guides = true })
	end

	-- Sync the current buffer with any available bookmarks, creating a right
	-- aligned virtual text chunk with the bookmark details.
	function self.buf_sync_bookmarks()
		local buf = vim.api.nvim_get_current_buf()
		local buf_name = vim.api.nvim_buf_get_name(buf)
		_buf_sync_bookmarks(buf, buf_name)
	end

	self.sync_aucmd = vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI" }, {
		callback = function()
			if not libws.is_current_ws(self.component.workspace) then
				return
			end
			self.buf_sync_bookmarks()
		end,
	})

	self.write_aucmd = vim.api.nvim_create_autocmd({ "BufWrite" }, {
		callback = function(args)
			self.write_bookmarks(args.file)
		end,
	})

	return self
end

return Notebook
