
local marked = {}

local function new_markup(markup_aliases)
    markup_aliases = markup_aliases or {}
    -- nil gets defaulted and false is for not including it metatable
    local key_alias = markup_aliases.key 
                      or markup_aliases.key == nil and "key" 
    local parent_alias = markup_aliases.parent 
                         or markup_aliases.parent == nil and "parent" 
    local children_alias = markup_aliases.children 
                           or markup_aliases.children == nil and "children" 

    local function markup(t, key, parent)
        assert(type(t) == "table")

        local function markup_index(t, key, parent)
            local prev = t
            local mt = getmetatable(t)
            while mt and not mt[marked] do
                prev = mt.__index
                mt = getmetatable(mt.__index)
            end
            if not mt then
                mt = {
                    [marked] = true,
                    __index = {}
                }
                if key_alias then
                    mt.__index[key_alias] = key or "root"
                end
                if parent_alias then
                    mt.__index[parent_alias] = parent
                end
                if children_alias then
                    mt.__index[children_alias] = {}
                end
                setmetatable(prev, mt)
            end
            return t
        end

        markup_index(t, key, parent)

        -- insert first the array elements
        local len = 0
        for i,v in ipairs(t) do
            len = len + 1
            if type(v) == "table" then
                markup(v, i, t)
                if children_alias then
                    table.insert(t[children_alias], v)
                end
            end
        end

        -- insert second the table (non-numeric) elements
        for k,v in pairs(t) do
            if type(v) == "table" and (type(k) ~= "number" or k > len or k < 1) then
                markup(v, k, t)
                if children_alias then
                    table.insert(t[children_alias], v)
                end
            end
        end

        return t
    end

    return markup
end

return new_markup
