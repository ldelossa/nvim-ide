local logger = require("ide.logger.logger")

local Node = {}

-- A Node is an interface for derived Nodes to implement.
--
-- A Node is a node within a @Tree and has polymorphic properties.
--
-- Nodes should be implemented based on the application's needs.
--
-- @type  - the type of the node, required.
-- @name  - the name of the node, required
-- @key   - a unique key representing this node.
-- @depth - the node's depth, useful if an external caller is building a tree
--          manually.
Node.new = function(type, name, key, depth)
	assert(type ~= nil, "cannot construct a Node without a type")
	assert(name ~= nil, "cannot construct a Node without a name")
	local self = {
		-- A potentially non-unique display name for the node.
		name = name,
		-- The depth of the node when it exists in a @Tree.
		depth = nil,
		-- A unique identifier for the node in a @Tree.
		key = nil,
		-- The parent of the Node.
		parent = nil,
		-- A list of self-similar Node(s) forming a tree structure.
		children = {},
		-- When present in a tree, whether the children nodes are accessible or not.
		expanded = true,
		-- Allows polymorphic behavior of a Node, allowing the type to be identified
		type = type,
		-- If marshalled, the line within the marshalled buffer this node was
		-- written to.
		line = nil,
		-- The tree the node belongs to
		tree = nil,
		-- a default logger that's set on construction.
		-- a derived class can set this logger instance and base class methods will
		-- derive a new logger from it to handle base class component level log fields.
		logger = logger.new("trees"),
	}
	if key ~= nil then
		self.key = key
	end
	if depth ~= nil then
		self.depth = depth
	end

	-- Marshal will marshal the Node into a buffer line.
	-- The function must return three objects to adhere to this interface.
	--
	-- returns:
	--  @icon   - An icon used to represent the Node in a UI.
	--  @name   - A display name used as the primary identifier of the node in the UI.
	--  @detail - A single line, displayed as virtual text, providing further details
	--            about the Node.
	--  @guide  - An override for the expand guide, if present, it will be used
	--            regardless of node's expanded field.
	--
	-- Returning empty strings for any of the above is valid and will result
	-- in the item no being displayed in the buffer line.
	self.marshal = function()
		error("method must be implemented")
	end

	-- Remove a child by its key.
	--
	-- @key - string, a unique key of the Node's child to remove.
	self.remove_child = function(key)
		local new_children = {}
		for _, c in ipairs(self.children) do
			if c.key ~= key then
				table.insert(new_children, c)
			end
		end
		self.children = (function()
			return {}
		end)()
		self.children = new_children
	end

	-- Return a Node's child by its key.
	--
	-- @key - string, the unique key of the child node to return.
	-- return:
	--  @Node | nil - the child node if found, nil if not.
	self.get_child = function(key)
		for _, c in ipairs(self.children) do
			if c.key == key then
				return c
			end
		end
		return nil
	end

	-- A function called to add children to a node on node expansion.
	--
	-- This is completely optional and implementation dependent.
	--
	-- If an expand function is implemented it *must* use the self.tree
	-- reference to add children, or if building the tree manually, recomputing
	-- the depth table.
	--
	-- This is a bit of an advanced use case so look at examples before
	-- implementing.
	--
	-- @opts - arbitrary table of options, implementation dependent.
	self.expand = function(opts)
		-- optionally implemented, no-op otherwise.
	end

	return self
end

return Node
