local tree = require("ide.trees.tree")
local filenode = require("ide.components.explorer.filenode")

local M = {}

function M.test_expand()
	vim.fn.delete("/tmp/filenode-testing", "rf")
	vim.fn.mkdir("/tmp/filenode-testing")
	vim.fn.chdir("/tmp/filenode-testing")
	vim.fn.writefile({}, "/tmp/filenode-testing/b")
	vim.fn.mkdir("/tmp/filenode-testing/c")

	local buf = vim.api.nvim_create_buf(true, false)
	local t = tree.new("explorer")
	t.buffer = buf

	local path = "/tmp/filenode-testing"
	local kind = vim.fn.getftype(path)
	local perms = vim.fn.getfperm(path)
	local fnode = filenode.new(path, kind, perms, 0)

	t.add_node(fnode, {})

	t.expand_node(fnode)

	assert(fnode.path == "/tmp/filenode-testing")
	assert(fnode.kind == "dir")
	assert(fnode.children[1].key == "/tmp/filenode-testing/b")
	assert(fnode.children[1].kind == "file")
	assert(fnode.children[2].key == "/tmp/filenode-testing/c")
	assert(fnode.children[2].kind == "dir")

	t.marshal()

	vim.fn.delete("/tmp/filenode-testing", "rf")
end

function M.test_touch()
	vim.fn.delete("/tmp/filenode-testing", "rf")
	vim.fn.mkdir("/tmp/filenode-testing")
	vim.fn.chdir("/tmp/filenode-testing")
	vim.fn.writefile({}, "/tmp/filenode-testing/b")
	vim.fn.mkdir("/tmp/filenode-testing/c")

	local buf = vim.api.nvim_create_buf(true, false)
	local t = tree.new("explorer")
	t.buffer = buf

	local path = "/tmp/filenode-testing"
	local kind = vim.fn.getftype(path)
	local perms = vim.fn.getfperm(path)
	local fnode = filenode.new(path, kind, perms, 0)

	t.add_node(fnode, {})

	t.expand_node(fnode)

	fnode.touch("d")

	t.expand_node(fnode)

	t.marshal()

	assert(fnode.children[3].key == "/tmp/filenode-testing/d")
	assert(fnode.children[3].kind == "file")

	vim.fn.delete("/tmp/filenode-testing", "rf")
end

function M.test_touch_overwrite()
	vim.fn.delete("/tmp/filenode-testing", "rf")
	vim.fn.mkdir("/tmp/filenode-testing")
	vim.fn.chdir("/tmp/filenode-testing")
	vim.fn.writefile({}, "/tmp/filenode-testing/b")

	local buf = vim.api.nvim_create_buf(true, false)
	local t = tree.new("explorer")
	t.buffer = buf

	local path = "/tmp/filenode-testing"
	local kind = vim.fn.getftype(path)
	local perms = vim.fn.getfperm(path)
	local fnode = filenode.new(path, kind, perms, 0)

	t.add_node(fnode, {})
	t.expand_node(fnode)
	fnode.touch("b")
	t.marshal()
end

function M.test_touch_overwrite_dir()
	vim.fn.delete("/tmp/filenode-testing", "rf")
	vim.fn.mkdir("/tmp/filenode-testing")
	vim.fn.chdir("/tmp/filenode-testing")
	vim.fn.mkdir("/tmp/filenode-testing/b")

	local buf = vim.api.nvim_create_buf(true, false)
	local t = tree.new("explorer")
	t.buffer = buf

	local path = "/tmp/filenode-testing"
	local kind = vim.fn.getftype(path)
	local perms = vim.fn.getfperm(path)
	local fnode = filenode.new(path, kind, perms, 0)

	t.add_node(fnode, {})
	t.expand_node(fnode)
	fnode.touch("b")
	t.marshal()
end

function M.test_mkdir()
	vim.fn.delete("/tmp/filenode-testing", "rf")
	vim.fn.mkdir("/tmp/filenode-testing")
	vim.fn.chdir("/tmp/filenode-testing")
	vim.fn.writefile({}, "/tmp/filenode-testing/b")
	vim.fn.mkdir("/tmp/filenode-testing/c")

	local buf = vim.api.nvim_create_buf(true, false)
	local t = tree.new("explorer")
	t.buffer = buf

	local path = "/tmp/filenode-testing"
	local kind = vim.fn.getftype(path)
	local perms = vim.fn.getfperm(path)
	local fnode = filenode.new(path, kind, perms, 0)

	t.add_node(fnode, {})

	t.expand_node(fnode)

	fnode.mkdir("d")

	t.expand_node(fnode)

	t.marshal()

	assert(fnode.children[3].key == "/tmp/filenode-testing/d")
	assert(fnode.children[3].kind == "dir")

	vim.fn.delete("/tmp/filenode-testing", "rf")
end

function M.test_mkdir_overwrite()
	vim.fn.delete("/tmp/filenode-testing", "rf")
	vim.fn.mkdir("/tmp/filenode-testing")
	vim.fn.chdir("/tmp/filenode-testing")
	vim.fn.writefile({}, "/tmp/filenode-testing/b")

	local buf = vim.api.nvim_create_buf(true, false)
	local t = tree.new("explorer")
	t.buffer = buf

	local path = "/tmp/filenode-testing"
	local kind = vim.fn.getftype(path)
	local perms = vim.fn.getfperm(path)
	local fnode = filenode.new(path, kind, perms, 0)

	t.add_node(fnode, {})
	t.expand_node(fnode)
	fnode.mkdir("b")
	t.marshal()
end

function M.test_rename()
	vim.fn.delete("/tmp/filenode-testing", "rf")
	vim.fn.mkdir("/tmp/filenode-testing")
	vim.fn.chdir("/tmp/filenode-testing")
	vim.fn.writefile({}, "/tmp/filenode-testing/b")
	vim.fn.mkdir("/tmp/filenode-testing/c")

	local buf = vim.api.nvim_create_buf(true, false)
	local t = tree.new("explorer")
	t.buffer = buf

	local path = "/tmp/filenode-testing"
	local kind = vim.fn.getftype(path)
	local perms = vim.fn.getfperm(path)
	local fnode = filenode.new(path, kind, perms, 0)

	t.add_node(fnode, {})
	t.expand_node(fnode)

	fnode.children[1].rename("x")

	assert(fnode.children[1].key == "/tmp/filenode-testing/x")
	assert(fnode.children[1].kind == "file")

	fnode.children[2].rename("y")
	assert(fnode.children[2].key == "/tmp/filenode-testing/y")
	assert(fnode.children[2].kind == "dir")

	t.marshal()
	vim.fn.delete("/tmp/filenode-testing", "rf")
end

function M.test_rm()
	vim.fn.delete("/tmp/filenode-testing", "rf")
	vim.fn.mkdir("/tmp/filenode-testing")
	vim.fn.chdir("/tmp/filenode-testing")
	vim.fn.writefile({}, "/tmp/filenode-testing/b")
	vim.fn.mkdir("/tmp/filenode-testing/c")

	local buf = vim.api.nvim_create_buf(true, false)
	local t = tree.new("explorer")
	t.buffer = buf

	local path = "/tmp/filenode-testing"
	local kind = vim.fn.getftype(path)
	local perms = vim.fn.getfperm(path)
	local fnode = filenode.new(path, kind, perms, 0)

	t.add_node(fnode, {})
	t.expand_node(fnode)

	fnode.children[1].rm()
	-- not a typo, we expect the top rm to only leave one item left
	fnode.children[1].rm()

	assert(#fnode.children == 0)
	assert(#vim.fn.glob("/tmp/filenode-testing/b") == 0)
	assert(#vim.fn.glob("/tmp/filenode-testing/c") == 0)

	t.marshal()
	vim.fn.delete("/tmp/filenode-testing", "rf")
end

function M.test_recursive_cp()
	-- start with...
	--[[
        .
        ├── a
        └── b
            ├── c
            │   └── z
            ├── x
            └── y
    ]]
	-- end with...
	--[[
        .
        ├── a
        │   └── b
        │       ├── c
        │       │   └── z
        │       ├── x
        │       └── y
        └── b
            ├── c
            │   └── z
            ├── x
            └── y
    ]]

	vim.fn.mkdir("/tmp/filenode-testing")
	vim.fn.mkdir("/tmp/filenode-testing/a")
	vim.fn.mkdir("/tmp/filenode-testing/b")
	vim.fn.mkdir("/tmp/filenode-testing/b/c")
	vim.fn.writefile({}, "/tmp/filenode-testing/b/x")
	vim.fn.writefile({}, "/tmp/filenode-testing/b/y")
	vim.fn.writefile({}, "/tmp/filenode-testing/b/c/z")
	vim.fn.chdir("/tmp/filenode-testing")

	local buf = vim.api.nvim_create_buf(true, false)
	local t = tree.new("explorer")
	t.buffer = buf

	local cwd = vim.fn.getcwd()
	local kind = vim.fn.getftype(cwd)
	local perms = vim.fn.getfperm(cwd)
	local fnode = filenode.new(cwd, kind, perms, 0)

	t.add_node(fnode, {})
	t.expand_node(fnode)

	local node_a = fnode.children[1]
	local node_b = fnode.children[2]

	-- recursive copy node_b into node_a
	node_b.cp(node_a)
	node_a.children[1].expand()

	assert(node_a.children[1].key == "/tmp/filenode-testing/a/b")
	assert(node_a.children[1].children[1].key == "/tmp/filenode-testing/a/b/c")
	assert(node_a.children[1].children[2].key == "/tmp/filenode-testing/a/b/x")
	assert(node_a.children[1].children[3].key == "/tmp/filenode-testing/a/b/y")
	node_a.children[1].children[1].expand()
	assert(node_a.children[1].children[1].children[1].key == "/tmp/filenode-testing/a/b/c/z")

	t.marshal()

	vim.fn.delete("/tmp/filenode-testing", "rf")
end

-- NOTE: needs user input, don't run automated.
function M.test_recursive_cp_overwrite()
	-- start with...
	--[[
        .
        ├── a/b
        └── b
            ├── c
            │   └── z
            ├── x
            └── y
    ]]
	-- end with...
	--[[
        .
        ├── a
        │   └── {user input}
        │       ├── c
        │       │   └── z
        │       ├── x
        │       └── y
        └── b
            ├── c
            │   └── z
            ├── x
            └── y
    ]]

	vim.fn.mkdir("/tmp/filenode-testing")
	vim.fn.mkdir("/tmp/filenode-testing/a")
	vim.fn.mkdir("/tmp/filenode-testing/a/b") -- will cause overwrite user prompt
	vim.fn.mkdir("/tmp/filenode-testing/b")
	vim.fn.mkdir("/tmp/filenode-testing/b/c")
	vim.fn.writefile({}, "/tmp/filenode-testing/b/x")
	vim.fn.writefile({}, "/tmp/filenode-testing/b/y")
	vim.fn.writefile({}, "/tmp/filenode-testing/b/c/z")
	vim.fn.chdir("/tmp/filenode-testing")

	local buf = vim.api.nvim_create_buf(true, false)
	local t = tree.new("explorer")
	t.buffer = buf

	local cwd = vim.fn.getcwd()
	local kind = vim.fn.getftype(cwd)
	local perms = vim.fn.getfperm(cwd)
	local fnode = filenode.new(cwd, kind, perms, 0)

	t.add_node(fnode, {})
	t.expand_node(fnode)

	local node_a = fnode.children[1]
	local node_b = fnode.children[2]

	-- recursive copy node_b into node_a
	node_b.cp(node_a)

	t.marshal()
end

function M.test_recursive_mv()
	-- start with...
	--[[
        .
        ├── a
        └── b
            ├── c
            │   └── z
            ├── x
            └── y
    ]]
	-- end with...
	--[[
        .
        ├── a
        │   └── b
        │       ├── c
        │       │   └── z
        │       ├── x
        │       └── y
    ]]

	vim.fn.mkdir("/tmp/filenode-testing")
	vim.fn.mkdir("/tmp/filenode-testing/a")
	vim.fn.mkdir("/tmp/filenode-testing/b")
	vim.fn.mkdir("/tmp/filenode-testing/b/c")
	vim.fn.writefile({}, "/tmp/filenode-testing/b/x")
	vim.fn.writefile({}, "/tmp/filenode-testing/b/y")
	vim.fn.writefile({}, "/tmp/filenode-testing/b/c/z")
	vim.fn.chdir("/tmp/filenode-testing")

	local buf = vim.api.nvim_create_buf(true, false)
	local t = tree.new("explorer")
	t.buffer = buf

	local cwd = vim.fn.getcwd()
	local kind = vim.fn.getftype(cwd)
	local perms = vim.fn.getfperm(cwd)
	local fnode = filenode.new(cwd, kind, perms, 0)

	t.add_node(fnode, {})
	t.expand_node(fnode)

	local node_a = fnode.children[1]
	local node_b = fnode.children[2]

	-- recursive copy node_b into node_a
	node_b.mv(node_a)

	assert(#fnode.children == 1)
	assert(fnode.children[1].path == "/tmp/filenode-testing/a")
	assert(#fnode.children[1].children == 1)
	assert(fnode.children[1].children[1].path == "/tmp/filenode-testing/a/b")
	t.expand_node(fnode.children[1].children[1])
	assert(#fnode.children[1].children[1].children == 3)
	assert(fnode.children[1].children[1].children[1].path == "/tmp/filenode-testing/a/b/c")
	t.expand_node(fnode.children[1].children[1].children[1])
	assert(fnode.children[1].children[1].children[1].children[1].path == "/tmp/filenode-testing/a/b/c/z")
	assert(fnode.children[1].children[1].children[2].path == "/tmp/filenode-testing/a/b/x")
	assert(fnode.children[1].children[1].children[3].path == "/tmp/filenode-testing/a/b/y")

	t.marshal()

	vim.fn.delete("/tmp/filenode-testing", "rf")
end

return M
