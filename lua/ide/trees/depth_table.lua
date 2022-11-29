local DepthTable = {}

-- A DepthTable allows quick searching for nodes at a known tree depth.
--
-- This can be useful when you need to find a Node at a known depth or you need
-- to quickly get a list of all nodes at a given depth.
DepthTable.new = function()
    local self = {
        table = {
            ['0'] = {},
        },
    }

    local function recursive_refresh(node)
        local depth = node.depth
        if self.table[depth] == nil then
            self.table[depth] = {}
        end

        table.insert(self.table[depth], node)

        -- recurse
        for _, child in ipairs(node.children) do
            recursive_refresh(child)
        end
    end

    function self.refresh(root)
        self.table = (function() return {} end)()
        recursive_refresh(root)
    end

    -- Search the DepthTable for a node with the @key at the given @depth
    --
    -- @depth - integer, the depth at which to search for @key
    -- @key   - the unique @Node.key to search for.
    -- return: @Node, @int - The node if found and the index within the array at
    --         the searched depth.
    function self.search(depth, key)
        local nodes = self.table[depth]
        if nodes == nil then
            return nil
        end
        for i, node in ipairs(nodes) do
            if node.key == key then
                return node, i
            end
        end
        return nil
    end

    return self
end


return DepthTable
