local IconSet = {}

local prototype = {
    icons = {
        Account        = "๐ฃ",
        Array          = "\\[\\]",
        Bookmark       = "๐",
        Boolean        = "โง",
        Calendar       = "๐",
        Check          = "โ",
        CheckAll       = "๐ธ๐ธ",
        Circle         = "๐",
        CircleFilled   = "โ",
        CirclePause    = "โฆท",
        CircleSlash    = "โ",
        CircleStop     = "โฆป",
        Class          = "c",
        Collapsed      = "โถ",
        Color          = "๐",
        Comment        = "๐ฉ",
        CommentExclaim = "๐ฉ",
        Constant       = "c",
        Constructor    = "c",
        DiffAdded      = "+",
        Enum           = "ฮ",
        EnumMember     = "ฮ",
        Event          = "๐ฒ",
        Expanded       = "โผ",
        Field          = "๐",
        File           = "๐",
        Folder         = "๐",
        Function       = "ฦ",
        GitBranch      = " ",
        GitCommit      = "โซฐ",
        GitCompare     = "โค",
        GitIssue       = "โ",
        GitMerge       = "โซฐ",
        GitPullRequest = "โฌฐ",
        GitRepo        = "๐ฎ",
        History        = "โฒ",
        IndentGuide    = "โ",
        Info           = "๐",
        Interface      = "I",
        Key            = "๎ฌ",
        Keyword        = "๎ฌ",
        Method         = "๎ช",
        Module         = "M",
        MultiComment   = "๐ฉ",
        Namespace      = "N",
        Notebook       = "๐ฎ",
        Notification   = "๐ญ",
        Null           = "โ",
        Number         = "#",
        Object         = "{}",
        Operator       = "O",
        Package        = "{}",
        Pass           = "๐ธ",
        PassFilled     = "๐ธ",
        Pencil         = "๎ฉณ",
        Property       = "๐ ",
        Reference      = "โ",
        RequestChanges = "โจช",
        Separator      = "โข",
        Space          = " ",
        String         = [[""]],
        Struct         = "{}",
        Sync           = "๐",
        Text           = [[""]],
        Terminal       = "๐ณ",
        TypeParameter  = "T",
        Unit           = "U",
        Value          = "v",
        Variable       = "V",
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
    set_icon = function(name, icon) end
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
            hi = "Identifier"
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
