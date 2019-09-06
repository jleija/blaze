local function is_empty(t)
    for _, _ in pairs(t) do
        return false
    end
    return true
end

local function new_markup(config)
    config = config or {}
    -- nil gets defaulted and false is for not including it in metatable
    local key_alias = config.key_alias 
                      or config.key_alias == nil and "key" 
    local parent_alias = config.parent_alias 
                         or config.parent_alias == nil and "parent" 
    local children_alias = config.children_alias 
                           or config.children_alias == nil and "children" 
    local root_alias = config.root_key_alias 
                        or config.root_key_alias == nil and "root"
    local plurals = config.plurals or {}
    local ownership = config.ownership or {}

    local reserved_keys = {}
    if key_alias then reserved_keys[key_alias] = true end
    if parent_alias then reserved_keys[parent_alias] = true end
    if children_alias then reserved_keys[children_alias] = true end

    local function markup(t, key, parent)
        assert(type(t) == "table")

        local marked = {}

        local function markup_index(t, key, parent)
            local owner = ownership[key]
            if not marked[t] and (not parent 
                    or owner and parent[owner] 
                    or is_empty(plurals) and is_empty(ownership)
                    or plurals[parent.key] 
                       or parent.parent and plurals[parent.parent.key]
                    or type(key) ~= "number" and not owner) then
                key = key or root_alias
                local old_mt = getmetatable(t)

                local mt = {
                    marked = marked,
                    __index = {}
                }
                if key_alias and type(key) == "string" then
                    mt.__index[key_alias] = key
                end
                if key_alias and type(key) == "number" then
                    assert(parent, "Can't give a singular key name at root array")
                    -- TODO: some features are dependent on having some
                    -- navigation like this one, where parent_alias is
                    -- necessary to resolve plurals in arrays.
                    -- Think about this and find a good solution
                    assert(parent_alias, "for now a parent_alias is necessary")
                    local p = parent
                    while p and not plurals[p[key_alias]] do
                        p = p[parent_alias]
                    end
                    if p then
                        mt.__index[key_alias] = plurals[p[key_alias]]
                    else
                        mt.__index[key_alias] = key
                    end
                end
                if parent_alias then
                    mt.__index[parent_alias] = parent
                end
                if children_alias then
                    mt.__index[children_alias] = {}
                end
                setmetatable(t, mt)
                if parent then
                    local mt_mt = {
                        __index = function(t, k)
                            local p = t
                            while p and p[key_alias] ~= k do
                                p = p[parent_alias]
                            end
                            return p
                        end
                    }
                    setmetatable(mt_mt, old_mt)
                    setmetatable(mt.__index, mt_mt)
                else
                    setmetatable(mt.__index, old_mt)
                end

                marked[t] = true
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
                if children_alias and t[children_alias] then
                    table.insert(t[children_alias], v)
                end
            end
        end

        -- insert second the table (non-numeric) elements in ascending order
        -- (to enforce predictable order)
        local named_keys = {}
        for k,v in pairs(t) do
            if reserved_keys[k] then
                error("Key '" .. k .. "' clashes with markup key, in element '" 
                        .. key .. "'. Use constructor to override markup words/keys")
            end
            if type(k) == "table" or type(k) == "function" then
                error("Invalid key of type " .. type(k) .. ", in element '"
                        .. key .. "'")
            end
            if type(v) == "table" and (type(k) ~= "number" or k > len or k < 1) then
                table.insert(named_keys, k)
            end
        end
        table.sort(named_keys)
        for _, k in ipairs(named_keys) do
            local v = t[k]
            markup(v, k, t)
            if children_alias and t[children_alias] then
                table.insert(t[children_alias], v)
            end
        end

        return t
    end

    return markup
end

return new_markup
