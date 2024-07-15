local async_client = require("ide.lib.async_client")

local Git = {}

Git.RECORD_SEP = "␞"
Git.GROUP_SEP = "␝"

local is_repo = nil
local last_dir = ""

-- Compares two shas by truncating each one to the min character length
-- provided and performing a string comparison.
--
-- @sha_a, @sha_b   - a git object's sha.
-- returns:
--                  - @bool - whether the two sha(s) are the same.
function Git.compare_sha(sha_a, sha_b)
	local min = #sha_a
	if #sha_b < min then
		min = #sha_b
	end
	if #sha_a > min then
		sha_a = vim.fn.strcharpart(sha_a, 0, min)
	end
	if #sha_b > min then
		sha_b = vim.fn.strcharpart(sha_a, 0, min)
	end
	return (sha_a == sha_b)
end

function Git.short_sha(sha)
	return sha:sub(1, 7)
end

function Git.in_git_repo()
	local cwd = vim.fn.getcwd()
	if is_repo == nil or cwd ~= last_dir then
		vim.fn.system("git rev-parse --is-inside-work-tree")
		is_repo = (vim.v.shell_error == 0)
		last_dir = cwd
	end
	return is_repo
end

function Git.repo_has_commits()
	vim.fn.system("git log -n 1")
	return (vim.v.shell_error == 0)
end

Git.new = function()
	local self = async_client.new("git")

	local function handle_req(callback)
		return function(req)
			if req.error then
				vim.notify(string.format("%s\n%s", req.reason, req.stderr), vim.log.levels.ERROR, {
					title = "git",
				})
				callback(nil)
				return
			end
			callback(req.stdout)
		end
	end

	function self.if_in_git_repo(cb)
		local cwd = vim.fn.getcwd()
		if is_repo == nil or cwd ~= last_dir then
			self.make_request(string.format("rev-parse --is-inside-work-tree"), nil, function(resp)
				last_dir = cwd
				if resp == nil or resp.error then
					is_repo = false
					return
				end
				is_repo = true
				cb()
			end)
		elseif is_repo then
			cb()
		end
	end

	-- issues a git log with a specified --format string.
	--
	-- the @format param must be an array of format specifiers as outlined in
	-- `man git log`.
	--
	-- each format specifier will be concat'd into a format string with the
	-- ASCII record separator character "␞" as a delimiter.
	--
	-- the returned output can then be split on the record separator character
	-- to obtain each field in the format specifier.
	--
	-- @format - @table, an array of format specifies as outlined in `man git log`
	-- @args   - @string, any additional arguments to supply to the `git log` command.
	-- @cb     - @function(table|nil) - an array of `git log` lines or nil if
	--           if a non zero exit code was encountered.
	function self.log_format(format, args, cb)
		local separated = ""
		for i, fspec in ipairs(format) do
			separated = separated .. fspec
			if i ~= #format then
				separated = separated .. Git.RECORD_SEP
			end
		end
		self.make_nl_request(string.format("log --format=%s %s", separated, args), nil, handle_req(cb))
	end

	-- Return the information retrieved by a default `git log` command.
	--
	-- @rev - @string, a git revision as described by `man gitrevision.7`
	-- @n   - @int, the number of commits to retrieve starting from `rev`.
	--        -1 can be used to return all commits relative to `rev`.
	-- @cb  - function(table|nil) - an array of tables with the following
	--        fields:
	--        - sha     - @string, the full commit sha
	--        - author  - @string, the author's full name
	--        - email   - @string, the author's email
	--        - date    - @string, date of the commit in ISO format.
	--        - subject - @string, the subject of the commit
	--        - body    - @string, body of the commit
	function self.log(rev, n, cb)
		local separated = ""
		local format = { "%H", "%an", "%ae", "%aD", "%s", "%b" }
		for i, fspec in ipairs(format) do
			separated = separated .. fspec
			if i ~= #format then
				separated = separated .. Git.RECORD_SEP
			else
				separated = separated .. Git.GROUP_SEP
			end
		end

		self.make_request(string.format("log -n %d --format=%s %s", n, separated, rev), nil, function(resp)
			if resp == nil then
				cb(nil)
			end
			local out = {}
			local commits = vim.fn.split(resp.stdout, Git.GROUP_SEP)
			for _, commit in ipairs(commits) do
				local parts = vim.fn.split(commit, Git.RECORD_SEP)
				for i = 0, 6, 1 do
					if parts[i] == nil then
						parts[i] = ""
					end
				end
				table.insert(out, {
					sha = parts[1],
					author = parts[2],
					email = parts[3],
					date = parts[4],
					subject = parts[5],
					body = parts[6],
				})
				::continue::
			end
			cb(out)
		end)
	end

	-- Returns a list of commit for the current repository.
	--
	-- @skip - @int, the number of returned commits to skip, used for paging.
	-- @n    - @int, the number of commits to return, used for paging.
	-- @cb   - function(table|nil), a callback function issued with the results.
	--         table is an array of commit tables with the following fields:
	--          sha     - @string, the abbreviated commit sha
	--          author  - @string, the name of the author of the commit
	--          subject - @string, the single line subject header of the commit
	--                    messages
	--          date    - @string, full date at which the commit was created.
	function self.log_commits(skip, n, cb)
		self.log_format(
			-- abbrev sha, author name, subject, relative date.
			{ "%H", "%an", "%s", "%cr", "%d"},
			string.format("--skip=%d -n %d", skip, n),
			function(stdout)
				if stdout == nil then
					cb(nil)
					return
				end
				local commits = {}
				for _, commit in ipairs(stdout) do
					local parts = vim.fn.split(commit, Git.RECORD_SEP)
					table.insert(commits, {
						sha = parts[1],
						author = parts[2],
						subject = parts[3],
						date = parts[4],
						tags = parts[5]
					})
				end
				cb(commits)
			end
		)
	end

	-- Get all commits with have manipulated the file at `path` in reverse
	-- chronological order.
	--
	-- @path - @string, a path, relative to the root of the git repository,
	-- @skip - @int, the number of returned commits to skip, used for paging.
	-- @n    - @int, the number of commits to return, used for paging.
	-- @cb   - function(table|nil), a callback function issued with the results.
	--         if not nil, an array of tables describing the
	--         commit in the context of a history.
	--         table fields:
	--          sha     - @string, the abbreviated commit sha
	--          author  - @string, the name of the author of the commit
	--          subject - @string, the single line subject header of the commit
	--                    messages
	--          date    - @string, the relative time (from time of the issued command)
	--                    the commit was created.
	function self.log_file_history(path, skip, n, cb)
		self.log_format(
			-- abbrev sha, author name, subject, relative date.
			{ "%H", "%an", "%s", "%cr" },
			string.format("--skip=%d -n %d -- %s", skip, n, path),
			function(stdout)
				if stdout == nil then
					cb(nil)
					return
				end
				local commits = {}
				for _, commit in ipairs(stdout) do
					local parts = vim.fn.split(commit, Git.RECORD_SEP)
					table.insert(commits, {
						sha = parts[1],
						author = parts[2],
						subject = parts[3],
						date = parts[4],
					})
				end
				cb(commits)
			end
		)
	end

	-- Returns the contents of file `path` at `rev` as an array of lines.
	--
	-- @rev     - @string, a git revision as defined in `man gitrevision.7`
	-- @path    - @string, a path, relative to the root, of the repository of a file
	--            to display at `rev`.
	-- @cb      - function(table|nil), a callback called with an array of strings,
	--            each of which are a line within `path` at `rev`.
	--            nil if a non-zero exit code is encountered.
	function self.show_file(rev, path, cb, staging)
		local req = ""
		if staging then
			req = string.format("show :0:%s", path)
		else
			req = string.format("show %s:%s", rev, path)
		end

		self.make_nl_request(req, nil, function(req)
			-- if we encounter an error, it most likely means the file is
			-- not present at rev, so return empty file contents.
			if req.error then
				cb({})
				return
			end
			cb(req.stdout)
		end)
	end

	-- Returns a list of tables expressing any changed files status for the
	-- current repository.
	--
	-- This command uses the --porcelain flag to obtain a stripped down
	-- list of statuses.
	--
	-- @cb  - function(table|nil), if table is not nil, an array of file status
	--        tables with the following keys:
	--          staged_status   - @string, if the file is staged, the status indicator.
	--          unstaged_status - @string, if the file is unstaged, the status indicator.
	--          status          - @string, the combined status indicator which is a two character
	--                            string expressing both staged and unstaged status.
	--          path            - @string, relative path to the file being described.
	function self.status(cb)
		local parse = function(data)
			local out = {}
			for _, d in ipairs(data) do
				local staged_status = vim.fn.strpart(d, 0, 1)
				local unstaged_status = vim.fn.strpart(d, 1, 1)
				local path = vim.fn.strpart(d, 3)
				local status = (function()
					local status = nil
					if staged_status == "" then
						status = " "
					else
						status = staged_status
					end
					if unstaged_status == "" then
						status = status .. " "
					else
						status = status .. unstaged_status
					end
					return status
				end)()
				local stat = {
					staged_status = staged_status,
					unstaged_status = unstaged_status,
					status = status,
					path = path,
				}
				table.insert(out, stat)
			end
			return out
		end

		self.make_nl_request(string.format("status --porcelain"), nil, function(req)
			if req.error then
				return
			end
			if req.exit_code ~= 0 then
				cb(nil)
				return
			end
			local out = parse(req.stdout)
			cb(out)
		end)
	end

	-- Add a file path to the staging area.
	--
	-- @path - @string, the relative path of a file within the repository.
	-- @cb   - @function(string|nil) - A value, which if not nil, means successful.
	function self.git_add(path, cb)
		self.make_request(string.format("add %s", path), nil, handle_req(cb))
	end

	-- Restore the given path to its original contents.
	-- Must specify if the restore is for the path in the staging area or not.
	--
	-- @staged  - @bool, if true, restore from the staged files, if false restore
	--            from the working tree.
	-- @path    - @string, the relative path to the file to restore.
	-- @cb      - @function(string|nil) - A value, which if not nil, means successful.
	function self.git_restore(staged, path, cb)
		local cmd = ""
		if staged then
			cmd = string.format("restore --staged %s", path)
		else
			cmd = string.format("restore %s", path)
		end
		self.make_request(cmd, nil, handle_req(cb))
	end

	-- List the files changed in a particular git-rev.
	--
	-- @rev - @string, a git revision as described by "man gitrevision.7"
	-- @cb  - @function(table|nil), if not nil, a table of file paths and their
	--        gitrevision. The table has the following fields:
	--          rev     - @string, the gitrevision being specified
	--          path    - @string, the file path edited by this commit.
	function self.show_rev_paths(rev, cb)
		self.make_nl_request(
			string.format("show %s --name-only --oneline", rev),
			nil,
			handle_req(function(paths)
				local out = {}
				for i, path in ipairs(paths) do
					if i ~= 1 then
						table.insert(out, {
							rev = rev,
							path = path,
						})
					end
				end
				cb(out)
			end)
		)
	end

	-- List the branches in the current repository.
	--
	-- @cb  - @function(table|nil), if not nil, a table of branches
	--        The table has the following fields:
	--          sha     - @string, the abbreviated sha of the branch object.
	--          branch  - @string, the branch's name
	--          is_head - @bool, whether this branch is the current HEAD.
	--          remote  - @string, the remote the branch tracks
	--          remote_branch - @string, the remote branch name at remote
	--          remote_ref - @string, the full remote ref in {origin}/{branch} format
	--          tracking - @string, the tracking status of the remote, 'ahead', 'behind',
	--                     'diverged', or 'sync'
	function self.branch(cb)
		self.make_nl_request(
			"for-each-ref refs/heads --format=%(HEAD)␞%(objectname)␞%(refname:short)␞%(upstream:short)␞%(upstream:trackshort)",
			nil,
			handle_req(function(branches)
				local out = {}
				for _, b in ipairs(branches) do
					b = vim.fn.split(b, Git.RECORD_SEP, true)
					local tracking = ""
					if b[5] == "<" then
						tracking = "behind"
					end
					if b[5] == ">" then
						tracking = "ahead"
					end
					if b[5] == "<>" then
						tracking = "diverged"
					end
					if b[5] == "=" then
						tracking = "sync"
					end

					local remote_parts = vim.fn.split(b[4], "/")
					local remote = remote_parts[1]
					local remote_branch = ""
					for i = 2, #remote_parts, 1 do
						if i ~= 2 then
							remote_branch = remote_branch .. "/"
						end
						remote_branch = remote_branch .. remote_parts[i]
					end

					table.insert(out, {
						is_head = (b[1] == "*"),
						sha = b[2],
						branch = b[3],
						remote = remote,
						remote_branch = remote_branch,
						remote_ref = b[4],
						tracking = tracking,
					})
				end
				cb(out)
			end)
		)
	end

	-- Checkout the given rev
	--
	-- @rev     - @string, the gitrevision to checkout the current repository to.
	-- @cb      - @function(string|nil) - A value, which if not nil, means successful.
	function self.checkout(rev, cb)
		self.make_request(
			string.format("checkout %s", rev),
			nil,
			handle_req(function(data)
				cb(data)
			end)
		)
	end

	-- Create the provided branch and checkout the local repository to it.
	--
	-- @branch  - @string, The branch to create and checkout.
	-- @cb      - @function(string|nil) - A value, which if not nil, means successful.
	function self.checkout_branch(branch, cb)
		self.make_request(
			string.format("checkout -b %s", branch),
			nil,
			handle_req(function(data)
				cb(data)
			end)
		)
	end

	-- Return the full sha256 of the current HEAD.
	--
	-- @cb      - @function(string|nil) - The sha256 of the current head or a
	--            nil if an error occurred.
	function self.head(cb)
		self.make_request(
			string.format("rev-parse HEAD"),
			nil,
			handle_req(function(rev)
				rev = vim.fn.trim(rev, "\n")
				cb(rev)
			end)
		)
	end

	function self.remotes(cb)
		self.make_nl_request(
			string.format("remote"),
			nil,
			handle_req(function(remotes)
				cb(remotes)
			end)
		)
	end

	function self.pull(remote, branch, cb)
		self.make_request(string.format("pull %s %s", remote, branch), nil, handle_req(cb))
	end

	function self.push(remote, branch, cb)
		self.make_request(string.format("push %s %s", remote, branch), nil, handle_req(cb))
	end

	function self.set_upstream(branch, upstream_ref, cb)
		self.make_request(string.format("branch %s --set-upstream-to=%s", branch, upstream_ref), nil, handle_req(cb))
	end

	return self
end

return Git
