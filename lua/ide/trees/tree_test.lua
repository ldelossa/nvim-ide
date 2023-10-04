local tree = require("ide.trees.tree")
local node = require("ide.trees.node")

local M = {}

local test_cases = {
	{
		"▼ +  test_root",
		" ▼ -  test_c1",
		" ▼ -  test_c2",
	},
	{
		"▼ +  test_root",
		" ▼ -  test_c1",
		"  ▼ -  test_c1.1",
		" ▼ -  test_c2",
	},
	{
		"▼ -  test_c1",
		" ▼ -  test_c1.1",
	},
	{
		"▼ -  test_c1",
		" ▼ -  test_c1.1",
		"  ▼ -  test_c1.1.1",
	},
	{
		"▶ -  test_c1",
	},
	{
		"▼ -  test_c1",
		" ▼ -  test_c1.1",
		"  ▼ -  test_c1.1.1",
	},
	{
		"▶ -  test_c1",
	},
	{
		"▼ -  test_c1",
		" ▶ -  test_c1.1",
	},
	{
		"▼ -  test_c1",
		" ▼ -  test_c1.1",
		"   -  test_c1.1.1",
	},
	{
		" -  test_c1",
		"  -  test_c1.1",
		"   -  test_c1.1.1",
	},
	{
		"▼ -  test_c1",
	},
}

local function check_tc(n, buf)
	for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		local tc = test_cases[n]
		assert(tc[i] == l, "expected lines to match" .. "\n" .. tc[i] .. "\n" .. l)
	end
end

function M.test_functionality()
	-- marshal a basic 3 node tree.
	local root = node.new("test", "test_root", "test_root", 0)
	root.marshal = function()
		return "+", "test_root", "root node"
	end
	local c1 = node.new("test", "test_c1", "test_c1")
	c1.marshal = function()
		return "-", "test_c1", "test child 1"
	end
	local c2 = node.new("test", "test_c2", "test_c2")
	c2.marshal = function()
		return "-", "test_c2", "test child 2"
	end
	local t = tree.new("test")
	t.add_node(root, { c1, c2 })
	local buf = vim.api.nvim_create_buf(true, false)
	t.buffer = buf
	t.marshal()

	check_tc(1, buf)

	-- add a child to c1 node
	local c1_1 = node.new("test", "test_c1.1", "test_c1.1")
	c1_1.marshal = function()
		return "-", "test_c1.1", "test child 1.1"
	end
	t.add_node(c1, { c1_1 })
	t.marshal()
	check_tc(2, buf)

	-- reparent tree to test_c1
	t.reparent_node(c1)
	t.marshal()
	check_tc(3, buf)

	-- add a child to c1.1
	local c1_1_1 = node.new("test", "test_c1.1.1", "test_c1.1.1")
	c1_1_1.marshal = function()
		return "-", "test_c1.1.1", "test child 1.1.1"
	end
	t.add_node(c1_1, { c1_1_1 })
	t.marshal()
	check_tc(4, buf)

	-- collapse c1
	t.collapse_node(c1)
	t.marshal()
	check_tc(5, buf)

	-- expand c1
	t.expand_node(c1)
	t.marshal()
	check_tc(6, buf)

	-- recursive collapse subtree
	t.collapse_subtree(c1)
	t.marshal()
	check_tc(7, buf)

	-- expand, we expect the entire subtree to be collapsed.
	t.expand_node(c1)
	t.marshal()
	check_tc(8, buf)

	-- ensure a leaf node does not have an expand guide.
	t.expand_node(c1_1)
	t.marshal({
		no_guides = false,
		no_guides_leaf = true,
		icon_set = require("ide.icons.icon_set").new(),
	})
	check_tc(9, buf)

	-- ensure no guides are shown.
	t.expand_node(c1_1)
	t.marshal({
		no_guides = true,
		no_guides_leaf = true,
		icon_set = require("ide.icons.icon_set").new(),
	})
	check_tc(10, buf)

	-- ensure search key finds node.
	node = t.search_key(c1_1.key)
	assert(node.key == c1_1.key, "search did not locate c1_1 node.")

	-- ensure walk works
	local seen = {}
	t.walk_subtree(t.root, function(n)
		seen[n.key] = n
		return true
	end)
	assert(seen[c1.key] ~= nil, "node c1 was not seen in walk")
	assert(seen[c1_1.key] ~= nil, "node c1 was not seen in walk")
	assert(seen[c1_1_1.key] ~= nil, "node c1 was not seen in walk")

	-- ensure walk works from an arbitrary node.
	seen = (function()
		return {}
	end)()
	t.walk_subtree(c1_1, function(n)
		seen[n.key] = n
		return true
	end)
	assert(seen[c1.key] == nil, "node c1 was incorrectly seen in walk")
	assert(seen[c1_1.key] ~= nil, "node c1 was not seen in walk")
	assert(seen[c1_1_1.key] ~= nil, "node c1 was not seen in walk")

	-- ensure remove_subtree removes a subtree
	t.remove_subtree(c1)
	t.marshal()
	check_tc(11, buf)

	-- test unmarshal
	node = t.unmarshal(1)
	assert(node.key == c1.key, "expected line 1 to unmarshal to c1 node")
end

return M
