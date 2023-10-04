local node = require("ide.trees.node")
local icons = require("ide.icons")
local libpopup = require("ide.lib.popup")

local BookmarkNode = {}

local RECORD_SEP = "␞"
local GROUP_SEP = "␝"

function BookmarkNode.unmarshal_text(line)
	local parts = vim.fn.split(line, RECORD_SEP)
	if #parts ~= 5 then
		error("line does not contain enough bookmark records")
	end
	local bm = BookmarkNode.new(parts[1], parts[2], parts[3], parts[4], parts[5])
	-- When we are marhsalling from a line, its assumed we are reading directly
	-- from a file, so dirty is false and record the original_start_line to
	-- determine if we are back to the disk's representation if the bookmark moves.
	bm.dirty = false
	bm.original_start_line = bm.start_line
	return bm
end

BookmarkNode.new = function(file, start_line, end_line, title, note, depth)
	local key = string.format("%s:%d:%s", file, tonumber(start_line), title)
	local self = node.new("bookmark", title, key, depth)

	-- the path, relative to the project's root, which this bookmark was created
	-- in.
	self.file = file
	-- The starting line where the bookmark was created
	self.start_line = tonumber(start_line)
	-- Used to help determine if a bookmark node is dirty, when its start_line
	-- matches its original, it can be un-marked as dirty.
	self.original_start_line = nil
	-- The ending line where the bookmark was created.
	self.end_line = tonumber(end_line)
	-- The title of the bookmark
	self.title = title
	-- Additional note data (no new lines).
	self.note = note
	-- Whether this bookmark's in-memory representation matches its on-disk.
	-- If dirty, it should eventually be written to disk if the file is as well.
	self.dirty = true
	-- If the bookmark has been displayed in a buffer, this field is set with a
	-- a tuple of {bufnr, extmark_id, ns_id}
	self.mark = nil

	-- Marshal a bookmarknode into a buffer line.
	--
	-- @return: @icon - @string, icon for bookmark's kind
	--          @name - @string, bookmark's name
	--          @details - @string, bookmark's detail if exists.
	function self.marshal()
		local icon = icons.global_icon_set.get_icon("Bookmark")
		if self.depth == 0 then
			icon = icons.global_icon_set.get_icon("Notebook")
		end
		local name = self.title
		if self.depth ~= 0 then
			if self.dirty then
				name = "*" .. name
			end
		end
		local details = string.format("%s:%d:%d", vim.fn.fnamemodify(self.file, ":t"), self.start_line, self.end_line)
		if self.depth == 0 then
			details = ""
		end
		return icon, name, details
	end

	-- Marshal this bookmarknode to a line of text suitable for encoding a bookmark
	-- into a notebook file.
	function self.marshal_text()
		return string.format(
			"%s%s%d%s%d%s%s%s%s\n",
			self.file,
			RECORD_SEP,
			self.start_line,
			RECORD_SEP,
			self.end_line,
			RECORD_SEP,
			self.title,
			RECORD_SEP,
			self.note
		)
	end

	function self.details()
		local lines = {}

		table.insert(lines, string.format("%s %s", icons.global_icon_set.get_icon("Bookmark"), self.title))
		table.insert(
			lines,
			string.format("%s %s", icons.global_icon_set.get_icon("File"), self.file .. ":" .. self.start_line)
		)

		libpopup.until_cursor_move(lines)
	end

	return self
end

return BookmarkNode
