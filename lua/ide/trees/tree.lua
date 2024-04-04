local logger = require("ide.logger.logger")
local marshaller = require("ide.trees.marshaller")
local depth_table = require("ide.trees.depth_table")

local Tree = {}

Tree.new = function(type)
	local self = {
		-- The root @Node of the tree
		root = nil,
		-- An optional type of the tree.
		type = "",
		-- A table associating the tree's depth (0-n) with the list of @Node(s) at
		-- that depth.
		--
		-- useful for linear searches at a specific depth of the tree.
		depth_table = depth_table.new(),
		-- A buffer directly associated with the tree.
		--
		-- If a buffer is associated with a tree, the tree can be marshalled into
		-- lines and written to it.
		buffer = nil,
		-- A @Marshaller implementation used to marshal the @Tree into @Tree.buffer.
		marshaller = marshaller.new(),
	}
	if type ~= nil then
		self.type = type
	end

	-- Sets the Tree's buffer in which it will marshal itself into.
	--
	-- @buf - buffer id, a buffer in which the current tree's nodes will be
	--        marshalled into, providind a UI for the tree.
	--
	-- return: void
	function self.set_buffer(buf)
		self.buffer = buf
	end

	-- Return a buffer is one is set with set_buffer.
	--
	-- return: buffer id | nil, a buffer in which the current tree's nodes will be
	--         marshalled into, providind a UI for the tree.
	function self.get_buffer()
		return self.buffer
	end

	local function _node_search(Node)
		local found = nil
		if Node.depth ~= nil then
			-- try a quick search of dpt tree
			found = self.depth_table.search(Node.depth, Node.key)
		end
		if found == nil then
			-- try a slow search via walking
			found = self.search_key(Node.key)
		end
		return found
	end

	-- Add the provided @children to the tree as children of @parent, unless
	-- @external is true.
	--
	-- @parent      - A @Node at which @children will be attached linked to.
	--                if @parent.depth is set to 0 this indicates to @Tree that the
	--                caller is building a new tree and will discard the previous, if
	--                exists.
	-- @children    - An array of @Node which will be linked to @parent as its
	--                children.
	--                If @parent.depth is not 0, a search for @parent will be
	--                performed, and thus its expected @parent is an existing
	--                @Node in the @Tree.
	--                When constructing the @Node(s) in this array their depth's
	--                field should be left blank (if external is not used).
	--                Their depths will be computed when added to the parent.
	-- @opts        - A table of options which instruct add_node how to proceed.
	--                Fields:
	--                  external - A @bool. If set to true this indicates the tree's @Node
	--                  hierarchy has been built by the caller and this method
	--                  will remove the current @Tree.root and replace it with
	--                  @parent. The @children field is ignored.
	--
	--                  append - If true Append @children to the existing set of @parent's
	--                            children. If false, remove the current children in favor
	--                            of the provided @children array.
	function self.add_node(parent, children, opts)
		if opts == nil then
			opts = {
				external = false,
				append = false,
			}
		end

		-- external nodes are roots of trees built externally
		-- if this is true set the tree's root to the incoming parent
		-- and immediately return
		if opts["external"] then
			self.root = parent
			self.depth_table.refresh(self.root)
			return
		end

		-- if depth is 0 we are creating a new call tree, discard the old one
		-- by overwriting the current root, populate depth_table so fast lookup
		-- makes the double work here negligible.
		if parent.depth == 0 then
			self.root = parent
			parent.tree = self
			self.depth_table.refresh(self.root)
		end

		local pNode = _node_search(parent)

		if pNode == nil then
			error("could not find parent node in tree. key: " .. parent.key)
		end

		if not opts["append"] then
			pNode.children = (function()
				return {}
			end)()
		end

		local child_depth = pNode.depth + 1
		for _, c in ipairs(children) do
			c.depth = child_depth
			c.parent = parent
			c.tree = self
			table.insert(pNode.children, c)
		end
		self.depth_table.refresh(self.root)
	end

	function self.remove_subtree(root)
		local pNode = _node_search(root)
		if pNode == nil then
			return
		end
		-- remove node's children
		pNode.children = (function()
			return {}
		end)()
		self.depth_table.refresh(self.root)
	end

	-- Walks the subtree from @root and performs @action
	--
	-- @root - @Node, a root @Node to start the @Tree walk.
	--
	-- @action - @function(@Node), a function which is called at very node,
	--           including @root.
	--           @Node is the current node in the walk and can be manipulated
	--           within the @action function.
	--           The action function must return a @bool which if false, ends
	--           the walk.
	function self.walk_subtree(root, action)
		local pNode = _node_search(root)
		if pNode == nil then
			return
		end
		if not action(pNode) then
			return
		end
		for _, c in ipairs(pNode.children) do
			self.walk_subtree(c, action)
		end
	end

	-- Search for a @Node in the @Tree by its key.
	--
	-- @key - string, a unique key for a @Node in the tree.
	--
	-- return: @Node | nil
	function self.search_key(key)
		local found = nil
		self.walk_subtree(self.root, function(node)
			if node.key == key then
				found = node
				return false
			end
			return true
		end)
		return found
	end

	-- Expands the provided @Node
	--
	-- @Node - @Node, a node to expand in the @Tree
	function self.expand_node(Node)
		local pNode = _node_search(Node)
		if pNode == nil then
			return
		end
		-- the node can optionally perform an action on expanding for dynamic
		-- population of children.
		if pNode.expand ~= nil then
			pNode.expand()
			-- the implemented expand function may not have set the node's parent,
			-- (tho it should), be defensive and do it anyway.
			for _, c in ipairs(pNode.children) do
				c.parent = pNode
			end
		end
		pNode.expanded = true
	end

	-- Collapses the provided @Node
	--
	-- If any children nodes are expanded they will continue to be once @Node
	-- is expanded again.
	--
	-- @Node - @Node, a node to collapse in the @Tree
	function self.collapse_node(Node)
		local pNode = _node_search(Node)
		if pNode == nil then
			return
		end
		pNode.expanded = false
	end

	-- Collapses all @Node(s) from the @root down.
	--
	-- @root - @Node, the root node to collapse. All children will be collapsed
	--         from this root down.
	function self.collapse_subtree(root)
		self.walk_subtree(root, function(Node)
			Node.expanded = false
			return true
		end)
	end

	local function recursive_reparent(Node, depth)
		local pNode = _node_search(Node)
		if pNode == nil then
			return
		end
		-- we are the new root, dump the current root_node and
		-- set yourself
		if depth == 0 then
			self.root = pNode
			self.root.depth = 0
		end
		-- recurse to leafs
		for _, child in ipairs(pNode.children) do
			recursive_reparent(child, depth + 1)
			-- recursion done, update your depth
			child.depth = depth + 1
		end
		if depth == 0 then
			self.depth_table.refresh(self.root)
		end
	end

	-- Make @Node the new root of the @Tree
	--
	-- @Node - the @Node to make the new root of the @Tree.
	function self.reparent_node(Node)
		recursive_reparent(Node, 0)
	end

	function self.marshal(opts)
		if self.buffer == nil or (not vim.api.nvim_buf_is_valid(self.buffer)) then
			return
		end
		self.marshaller.marshal(self, opts)
	end

	-- When a tree has been marshalled into an associated buffer this method
	-- can return the @Node associated with the marshalled buffer line.
	--
	-- @linenr - integer, line number within @Tree.buffer.
	--
	-- return: @Node | nil, the node which associates with the marshalled buffer
	--         line.
	function self.unmarshal(linenr)
		if linenr == nil then
			error("cannot call unmarshal with a nil linenr")
		end
		local node = self.marshaller.unmarshal(linenr)
		return node
	end

	return self
end

return Tree
