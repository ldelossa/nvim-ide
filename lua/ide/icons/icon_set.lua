local IconSet = {}

local prototype = {
	icons = {
		Account = "🗣",
		Array = "\\[\\]",
		Bookmark = "🔖",
		Boolean = "∧",
		Calendar = "🗓",
		Check = "✓",
		CheckAll = "🗸🗸",
		Circle = "🞆",
		CircleFilled = "●",
		CirclePause = "⦷",
		CircleSlash = "⊘",
		CircleStop = "⦻",
		Class = "c",
		Code = "{}",
		Collapsed = "▶",
		Color = "🖌",
		Comment = "🗩",
		CommentExclaim = "🗩",
		Constant = "c",
		Constructor = "c",
		DiffAdded = "+",
		Enum = "Ε",
		EnumMember = "Ε",
		Event = "🗲",
		Expanded = "▼",
		Field = "𝐟",
		File = "🗀",
		Folder = "🗁",
		Function = "ƒ",
		GitBranch = " ",
		GitCommit = "⫰",
		GitCompare = "⤄",
		GitIssue = "⊙",
		GitMerge = "⫰",
		GitPullRequest = "⬰",
		GitRepo = "🕮",
		History = "⟲",
		IndentGuide = "│",
		IndentGuideEnd = "┕",
		Info = "🛈",
		Interface = "I",
		Key = "",
		Keyword = "",
		Method = "",
		Module = "M",
		MultiComment = "🗩",
		Namespace = "N",
		Notebook = "🕮",
		Notification = "🕭",
		Null = "∅",
		Number = "#",
		Object = "{}",
		Operator = "O",
		Package = "{}",
		Pass = "🗸",
		PassFilled = "🗸",
		Pencil = "",
		Property = "🛠",
		Reference = "⛉",
		RequestChanges = "⨪",
		Separator = "•",
		Space = " ",
		String = [[""]],
		Struct = "{}",
		Sync = "🗘",
		Text = [[""]],
		Terminal = "🖳",
		TypeParameter = "T",
		Unit = "U",
		Value = "v",
		Variable = "V",
	},
	-- Retrieves an icon by name.
	--
	-- @name - string, the name of an icon to retrieve.
	--
	-- return: string or nil, where string is the requested icon if exists.
	get_icon = function(name) end,
	-- Returns a table of all registered icons
	--
	-- return - table, keys are icon names and values are the icons.
	list_icons = function() end,
	-- Sets an icon.
	--
	-- This can add a new icon to the icon set and also overwrite an existing
	-- one.
	--
	-- returns - void
	set_icon = function(name, icon) end,
}

IconSet.new = function()
	local self = vim.deepcopy(prototype)

	function self.get_icon(name)
		return self.icons[name]
	end

	function self.list_icons()
		return self.icons
	end

	function self.set_win_highlights()
		for name, icon in pairs(self.list_icons()) do
			local hi = string.format("%s%s", "TS", name)
			if vim.fn.hlexists(hi) ~= 0 then
				vim.cmd(string.format("syn match %s /%s/", hi, icon))
				goto continue
			end
			hi = string.format("%s", name)
			if vim.fn.hlexists(hi) ~= 0 then
				vim.cmd(string.format("syn match %s /%s/", hi, icon))
				goto continue
			end
			hi = "Title"
			vim.cmd(string.format("syn match %s /%s/", hi, icon))
			::continue::
		end
	end

	function self.set_icon(name, icon)
		self.icons[name] = icon
	end

	return self
end

return IconSet
