local node = require("ide.trees.node")
local prompts = require("ide.components.explorer.prompts")
local logger = require("ide.logger.logger")
local sort = require("ide.lib.sort")

local FileNode = {}

local EXPAND_REFRESH_ONLY = { refresh_only = true }

FileNode.new = function(path, kind, perms, depth, opts)
	-- extends 'ide.trees.Node' fields.
	-- path can be used as both a name and key since its unique on the system.
	local self = node.new("file", path, path, depth)
	-- node options
	self.opts = vim.tbl_deep_extend("keep", opts or {}, {
		show_file_permissions = true,
	})
	-- the path to this file
	self.path = path
	-- the kind of file (regular, directory, device, etc..)
	self.kind = kind
	-- a rwx formatted permission string
	self.perms = perms
	-- determines if the node is currently selected
	self.selected = false
	-- important, the base class defaults to nodes being expanded on creation.
	-- we don't want this for FileNodes, since we dynamically fill a FileNode's
	-- children on expand.
	self.expanded = false

	-- Marshal a filenode into a buffer line.
	--
	-- @return: @icon - @string, icon used for file entry
	--          @name - @string, the name of the file
	--          @details - @string, the permissions of the file
	--          @guide - @string, a guide override, if a file (leaf) then an
	--                   empty expand guide is returned
	function self.marshal()
		local guide = " " -- only dirs will have a guide
		if self.kind == "dir" then
			guide = nil
		end

		local name = vim.fn.fnamemodify(self.path, ":t")
		if self.is_selected() then
			name = "+ " .. vim.fn.fnamemodify(self.path, ":t")
		end

		local icon = ""
		-- use webdev icons if possible
		if pcall(require, "nvim-web-devicons") then
			icon = require("nvim-web-devicons").get_icon(self.name, nil, { default = true })
			if self.kind == "dir" then
				icon = require("nvim-web-devicons").get_icon("dir")
			end
		else
			if self.kind ~= "dir" then
				icon = require("ide.icons").global_icon_set.get_icon("File")
			else
				icon = require("ide.icons").global_icon_set.get_icon("Folder")
			end
		end
		-- the above call to nvim-web-devicons could result in a nil, check and
		-- set back to string for safety
		if icon == nil then
			icon = " "
		end

		if self.opts.show_file_permissions or self.opts.show_file_permissions == nil then
			return icon, name, self.perms, guide
		else
			return icon, name, "", guide
		end
	end

	local function file_exists(path)
		if #vim.fn.glob(path) > 0 then
			return true
		else
			return false
		end
	end

	-- Expands a filenode async
	-- This can also be used to refresh the contents of a directory.
	--
	-- It is faster then self.expand() however to save time it will not try to
	-- retore any expanded nodes under `self`.
	--
	-- @opts - @table, options for the expand
	--         refresh_only - @bool, if true only refresh node's children, do not
	--                        set the node's expanded field to true.
	--
	-- return: void
	function self.expand_async(opts, cb)
		local log = self.logger.logger_from("explorer", "FileNode.expand_async")
		log.debug("expanding filenode %s", self.path)
		if opts == nil then
			opts = {
				refresh_only = false,
			}
		end
		if self.kind ~= "dir" then
			return
		end
		local handle = nil
		vim.uv.fs_opendir(self.path, function(err, dir)
			if err then
				return
			end
			vim.uv.fs_readdir(dir, function(err, entries)
				if err then
					return
				end

				if entries == nil or #entries == 0 then
					self.expanded = true
					if cb ~= nil then
						cb()
					end
					return
				end

				local children = {}
				for _, entry in ipairs(entries) do
					local child_path = self.path .. "/" .. entry.name
					local child_kind = "file"
					if entry.type == "directory" then
						child_kind = "dir"
					end
					local child_perms = vim.fn.getfperm(child_path)
					local fnode = FileNode.new(child_path, child_kind, child_perms, nil, vim.deepcopy(self.opts))
					table.insert(children, fnode)
				end

				sort(children, function(first, second)
					return first ~= second and first.kind == "dir" and second.kind ~= "dir"
				end)

				-- refresh our children in the tree.
				self.tree.add_node(self, children)

				-- if we only wanted to refresh the underlying tree, not expand the node
				-- return here.
				if opts.refresh_only then
					return
				end
				self.expanded = true

				if cb ~= nil then
					cb()
				end

				dir:closedir()
			end)
		end, math.pow(2, 16) - 1)
	end

	-- Expands a filenode.
	-- This can also be used to refresh the contents of a directory.
	--
	-- It is a slow synchronous function but it can also restore any previously
	-- expanded directories below `self`, unlike self.expand_async
	--
	-- Therefore, this is good to use after file operations on a specific directory
	-- as it won't collapse child directories on next marshal
	--
	-- @opts - @table, options for the expand
	--         refresh_only - @bool, if true only refresh node's children, do not
	--                        set the node's expanded field to true.
	--
	-- return: void
	function self.expand(opts)
		local log = self.logger.logger_from("explorer", "FileNode.expand")
		log.debug("expanding filenode %s", self.path)

		if opts == nil then
			opts = {
				refresh_only = false,
			}
		end

		if self.kind ~= "dir" then
			log.debug("filenode is not a directory, returning")
			return
		end

		local children = {}
		for _, child in ipairs(vim.fn.readdir(self.path)) do
			local child_path = self.path .. "/" .. child
			local child_kind = vim.fn.getftype(child_path)
			local child_perms = vim.fn.getfperm(child_path)

			local existing_node = self.tree.search_key(child_path)
			if existing_node then
				table.insert(children, existing_node)
				goto continue
			end

			local fnode = FileNode.new(child_path, child_kind, child_perms, nil, vim.deepcopy(self.opts))
			table.insert(children, fnode)
			::continue::
		end
		log.debug("found %d children", #children)

		sort(children, function(first, second)
			return first ~= second and first.kind == "dir" and second.kind ~= "dir"
		end)

		-- refresh our children in the tree.
		self.tree.add_node(self, children)

		-- if we only wanted to refresh the underlying tree, not expand the node
		-- return here.
		if opts.refresh_only then
			return
		end

		log.debug("filenode set to expanded")
		self.expanded = true
	end

	-- If self is a directory, create a file within it.
	--
	-- @name - @string, the name of the file to create as a child to this
	--         directory
	--
	-- return: void
	function self.touch(name, opts)
		local log = self.logger.logger_from("explorer", "FileNode.touch")
		log.debug("request to create file %s in %s", vim.inspect(name), self.path)

		if self.kind ~= "dir" then
			log.debug("filenode is not a directory, returning")
			return
		end

		local function touch(path, overwrite)
			if file_exists(path) then
				log.debug(
					"file to create exists, prompting user to rename or cancel, will callback into FileNode.touch."
				)
				-- you can't overwrite a directory so force a rename.
				if vim.fn.isdirectory(path) ~= 0 then
					prompts.must_rename(path, touch)
					return
				end
				-- it does, were we told to overwrite it?
				if not overwrite then
					-- we weren't, so prompt the user what to do and call yourself
					-- back.
					prompts.should_overwrite(path, touch)
					return
				end
			end

			-- if path ends with '/' create a directory instead
			if vim.endswith(path, "/") then
				self.mkdir(name)
			else
				local containing_dir = vim.fn.fnamemodify(path, ":p:h")
				if vim.fn.isdirectory(containing_dir) == 0 then
					self.mkdir(vim.fn.fnamemodify(name, ":h"))
				end

				if vim.fn.writefile({}, path) == -1 then
					error("failed to write file " .. path)
					return
				end
			end

			log.debug("successfully wrote file, expanding FileNode to retrieve created file.")
			-- expand self to regen child listing, will also create new filenode for
			-- child file.
			self.expand()
		end

		local child_path = self.path .. "/" .. name
		touch(child_path, false)
	end

	-- If self is a directory, create a directory within it.
	--
	-- @name - @string, the name of the directory to create as a child to this
	--         directory
	--
	-- return: void
	function self.mkdir(name, opts)
		local log = self.logger.logger_from("explorer", "FileNode.mkdir")
		log.debug("request directory create %s in %s", name, self.path)

		if self.kind ~= "dir" then
			return
		end
		local function mkdir(path)
			if file_exists(path) then
				log.debug("directory exist, prompting user to rename. will callback into FileNode.mkdir")
				prompts.must_rename(path, mkdir)
				return
			end
			if vim.fn.mkdir(path, "p") == -1 then
				error("failed to create directory " .. path)
				return
			end
			log.debug("successfully created directory, expanding FileNode to retrieve created directory.")
			-- expand self to regen child listing, will also create new filenode for
			-- child file.
			self.expand()
		end

		local child_path = self.path .. "/" .. name
		mkdir(child_path)
	end

	-- Rename this filenode.
	--
	-- @name - @string - the new file name
	--
	-- return: void
	function self.rename(name)
		local log = self.logger.logger_from("explorer", "FileNode.rename")
		log.debug("request rename from %s to %s", name, self.path)

		local path = vim.fn.fnamemodify(self.path, ":h")
		local new_path = path .. "/" .. name
		if vim.fn.rename(self.path, new_path) == -1 then
			error(string.format("failed renaming %s to %s", self.path, new_path))
		end
		self.path = new_path
		self.key = new_path
		self.name = new_path
		log.debug("successfully renamed file, expanding FileNode to retrieve created directory.")
		self.expand()
	end

	-- Remove this filenode.
	--
	-- return: void
	function self.rm()
		local log = self.logger.logger_from("explorer", "FileNode.rm")
		log.debug("request deletion of %s", self.path)

		if self.parent == nil then
			error("cannot remove project directory's root")
		end
		if vim.fn.delete(self.path, "rf") == -1 then
			error("failed to remove " .. self.path)
		end
		log.debug("deletion successful. expanding parent to get latest listing.", self.path)
		local new_children = {}
		for _, child in ipairs(self.parent.children) do
			if child.key ~= self.key then
				table.insert(new_children, child)
			end
		end
		self.parent.children = (function()
			return {}
		end)()
		self.parent.children = new_children
		self.parent.expand()
	end

	-- Recursively copy this filenode to the provided directory filenode.
	--
	-- @dir_node - @FileNode - the FileNode, which must be a directory, to copy
	--             ourselves to.
	--
	-- return: void
	function self.cp(dir_node)
		local log = self.logger.logger_from("explorer", "FileNode.rename")
		log.debug("request to copy %s to %s", self.path, dir_node.path)

		if dir_node.kind ~= "dir" then
			error("cannot copy a file into a non directory")
			return
		end
		local function cp(to, overwrite)
			-- check if the path to copy to exists
			if file_exists(to) then
				-- it does, were we told to overwrite it?
				if not overwrite then
					-- we weren't, so prompt the user what to do and call yourself
					-- back.
					log.debug("directory exists, prompting user to rename and calling back", self.path, dir_node.path)
					prompts.should_overwrite(to, cp)
					return
				end
			end

			-- if self is not a dir, this is a simple file copy.
			log.debug("performing non-recursive file copy")
			if self.kind ~= "dir" then
				if vim.fn.writefile(vim.fn.readfile(self.path), to) == -1 then
					error(string.format("failed to copy %s to %s", dir_node.path, to))
				end
				return
			end

			-- self is a dir, this is a recursive copy --

			log.debug("performing recursive file copy")
			log.debug("creating directory %s to copy children into", to)
			-- make the directory we're being copied to.
			if vim.fn.mkdir(to) == -1 then
				error(string.format("failed to copy directory %s to %s", self.path, to))
			end

			-- expand node we are being copied to in order to get the new directory
			-- node we just created.
			dir_node.expand()

			-- expand self to get latest children we'll be copying over to new_dir.
			self.expand(EXPAND_REFRESH_ONLY)

			-- get new_dir node so we can copy our children into it.
			local new_dir = dir_node.get_child(to)
			if new_dir == nil then
				error("failed to find copied directory " .. to)
			end

			log.debug("recursive copying children to %s", to)
			-- copy all our children into new_dir.
			for _, c in ipairs(self.children) do
				c.cp(new_dir)
			end
		end

		-- make copy-to path, self's filename prefixed by dir_node's path.
		local from_basename = vim.fn.fnamemodify(self.path, ":t")
		local to = dir_node.path .. "/" .. from_basename
		cp(to, false)
	end

	-- Recursively move this filenode to the provided directory filenode.
	--
	-- @dir_node - @FileNode - the FileNode, which must be a directory, to move
	--             ourselves to.
	--
	-- return: void
	function self.mv(dir_node)
		local log = self.logger.logger_from("explorer", "FileNode.rename")
		log.debug("request to move %s to %s", self.path, dir_node.path)

		if dir_node.kind ~= "dir" then
			error("cannot copy a file into a non directory")
			return
		end
		local function mv(to, overwrite)
			-- check if the path to copy to exists
			if file_exists(to) then
				-- it does, were we told to overwrite it?
				if not overwrite then
					-- we weren't, so prompt the user what to do and call yourself
					-- back.
					log.debug("directory exists, prompting user to rename and calling back", self.path, dir_node.path)
					prompts.should_overwrite(to, mv)
					return
				end
			end

			log.debug("performing non-recursive move")
			-- if self is not a dir, this is a simple file move.
			if self.kind ~= "dir" then
				if vim.fn.rename(self.path, to) ~= 0 then
					error(string.format("failed to move %s to %s", dir_node.path, to))
				end
				-- remove ourselves from our parent, we have been moved.
				log.debug("removing ourselves from parent %s", self.parent.path)
				self.parent.remove_child(self.key)
				return
			end

			log.debug("performing recursive move")
			-- self is a dir, this is a recursive move --

			-- make the directory we're being copied to.
			log.debug("creating directory %s to move children into", to)
			if vim.fn.mkdir(to) == -1 then
				error(string.format("failed to copy directory %s to %s", self.path, to))
			end

			-- expand node we are being copied to in order to get the new directory
			-- node we just created.
			dir_node.expand()
			-- expand self to get latest children we'll be copying over to new_dir.
			-- self.expand(EXPAND_REFRESH_ONLY)

			-- get new_dir node so we can copy our children into it.
			local new_dir = dir_node.get_child(to)
			if new_dir == nil then
				error("failed to find copied directory " .. to)
			end

			log.debug("recursive moving children to %s", to)
			-- move all our children into new_dir.
			for _, c in ipairs(self.children) do
				c.mv(new_dir)
				new_dir.expand()
			end

			-- all our children have been moved, remove ourselves
			self.rm()
			self.parent.remove_child(self.key)
		end

		-- make copy-to path, self's filename prefixed by dir_node's path.
		local from_basename = vim.fn.fnamemodify(self.path, ":t")
		local to = dir_node.path .. "/" .. from_basename
		mv(to, false)
	end

	-- Set this file node as selected
	--
	-- return: void
	function self.select()
		self.selected = true
	end

	-- Set this file node as unselected
	--
	-- return: void
	function self.unselect()
		self.selected = false
	end

	-- Return a bool indicating if the file is currently selected or not.
	--
	-- return: @bool
	function self.is_selected()
		return (self.selected == true)
	end

	return self
end

return FileNode
