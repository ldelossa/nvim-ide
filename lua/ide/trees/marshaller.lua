local icon_set = require('ide.icons').global_icon_set

Marshaller = {}

-- A Marshaller is responsible for taking a @Tree and marshalling its @Node(s)
-- into buffer lines, providing the user facing interface for a @Tree.
--
-- The Marshaller keeps track of which buffer lines associate with which @Node
-- in the @Tree and can be used for quick retrieval of a @Node given a buffer
-- line.
Marshaller.new = function()
    local self = {
        -- A mapping between marshalled buffer lines and their @Node which the line
        -- represents.
        buffer_line_mapping = {},
        -- A working array of buffer lines used during marshalling, eventually
        -- written out to the @Tree's buffer.
        buffer_lines = {},
        -- A working array of virtual text line descriptions, eventually applied to
        -- the lines in the @Tree's buffer.
        virtual_text_lines = {},
    }

    local function recursive_marshal(node, opts)
        local expand_guide = ""
        if node.expanded then
            expand_guide = icon_set.get_icon("Expanded")
        else
            expand_guide = icon_set.get_icon("Collapsed")
        end
        if opts.no_guides then
            expand_guide = ""
        end
        if opts.no_guides_leaf then
            if #node.children == 0 then
                expand_guide = " "
            end
        end

        local icon, name, detail, guide = node.marshal()

        -- pad detail a bit
        detail = detail .. " "

        if guide ~= nil then
            expand_guide = guide
        end

        local buffer_line = ""

        for _=1, node.depth do
            buffer_line = buffer_line .. icon_set.get_icon("Space")
        end

        buffer_line = buffer_line .. expand_guide .. icon_set.get_icon("Space")
        buffer_line = buffer_line .. icon .. icon_set.get_icon("Space")  .. icon_set.get_icon("Space") .. name

        table.insert(self.buffer_lines, buffer_line)
        self.buffer_line_mapping[#self.buffer_lines] = node
        node.line = #self.buffer_lines
        table.insert(self.virtual_text_lines,{{detail, "TSKeyword"}} )

        -- don't recurse if current node is not expanded.
        if not node.expanded then
            return
        end

        for _, c in ipairs(node.children) do
                recursive_marshal(c, opts)
        end
    end

    -- Kicks off the marshalling of the @Tree @Node(s) into the associated @Tree.buffer
    --
    -- Once this method completes a text representation of the @Tree will be present
    -- in @Tree.buffer.
    --
    -- @Tree - @Tree, an @Tree which has an associated and valid @Tree.buffer
    --        field.
    -- 
    -- @opts - A table providing options to the marshalling process
    --         Fields:
    --              no_guides - bool, do not display expand/collapsed guides
    --              no_guides_leaf - bool, if the marshaller can determine the
    --              node is a leaf, do not marshall an expand/collaped guide.
    -- returns: void
    function self.marshal(Tree, opts)
        if Tree.root == nil then
            error("attempted to marshal a tree with a nil root")
        end
        if Tree.buffer == nil or
            (not vim.api.nvim_buf_is_valid(Tree.buffer))
        then
            error("attempted to marshal a tree with invalid buffer " .. Tree.buffer)
        end

        if opts == nil then
            opts = {}
        end
        local o = {
            no_guides = false,
            no_guides_leaf = false,
            restore = nil,
            virt_text_pos = 'right_align',
            hl_mode = 'combine'
        }
        o = vim.tbl_extend("force", o, opts)

        -- zero out our bookkeepers
        self.buffer_line_mapping = (function() return {} end)()
        self.buffer_lines = (function() return {} end)()
        self.virtual_text_lines = (function() return {} end)()

        recursive_marshal(Tree.root, o)

        -- recursive marshalling done, now write out buffer lines and apply
        -- virtual text.
        vim.api.nvim_buf_set_option(Tree.buffer, 'modifiable', true)
        vim.api.nvim_buf_set_lines(Tree.buffer, 0, -1, true, {})
        vim.api.nvim_buf_set_lines(Tree.buffer, 0, #self.buffer_lines, false, self.buffer_lines)
        vim.api.nvim_buf_set_option(Tree.buffer, 'modifiable', false)
        for i, vt in ipairs(self.virtual_text_lines) do
            if vt[1][1] == "" then
                goto continue
            end
            local opts = {
                virt_text = vt,
                virt_text_pos = o.virt_text_pos,
                hl_mode = o.hl_mode,
            }
            vim.api.nvim_buf_set_extmark(Tree.buffer, 1, i-1, 0, opts)
            ::continue::
        end
    end

    -- Return the @Node associated with the marshalled line number.
    --
    -- @linenr - integer, the marshalled line number to which the @Node should 
    --           be returned.
    --
    -- return: @Node | nil.
    function self.unmarshal(linenr)
        return self.buffer_line_mapping[linenr]
    end

    function self.reset()
        self.buffer_line_mapping = (function() return {} end)()
        self.buffer_lines = (function() return {} end)()
        self.virtual_text_lines = (function() return {} end)()
    end

    return self
end

return Marshaller
