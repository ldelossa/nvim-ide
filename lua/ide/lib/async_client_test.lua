local client = require("ide.lib.async_client")

local uv = vim.loop

local M = {}

function M.test_stdout()
	-- use an echo client for testing.
	local c = client.new("echo")
	c.make_request("-n hello world", nil, function(result)
		print(vim.inspect(result))
		assert(result.error == false)
		assert(result.stderr == "")
		assert(result.stdout == "hello world")
	end)
	c.make_request(nil, nil, function(result)
		print(vim.inspect(result))
		assert(result.error == false)
		assert(result.stderr == "")
		assert(result.stdout == "\n")
	end)
	c.make_request("-n hello world", nil, function(result)
		print(vim.inspect(result))
		assert(result.error == false)
		assert(result.stderr == "")
		assert(#result.stdout == 2)
		assert(result.stdout[1] == "hello")
		assert(result.stdout[2] == "world")
	end, function(req)
		req.stdout = vim.fn.split(req.stdout)
	end)
	c.make_nl_request([[-n hello\nworld]], nil, function(result)
		print(vim.inspect(result))
		assert(result.error == false)
		assert(result.stderr == "")
		assert(#result.stdout == 2)
		assert(result.stdout[1] == "hello")
		assert(result.stdout[2] == "world")
	end)
	c.make_json_request([[-n {"hello": "world"}]], nil, function(result)
		print(vim.inspect(result))
		assert(result.error == false)
		assert(result.stderr == "")
		assert(result.stdout["hello"] == "world")
	end)
	-- test json_code fail
	c.make_json_request([[-n {"hello", "world"}]], nil, function(result)
		print(vim.inspect(result))
		assert(result.error == true)
		assert(result.stderr == "")
	end)
end

return M
