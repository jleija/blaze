local function simple_table_to_string(t)
    local out = {}
    for k, v in pairs(t) do
        table.insert(out, k .. " = " .. tostring(v))
    end
    return "{" .. table.concat(out, ", ") .. "}"
end

local function is_empty(t)
    for _, _ in pairs(t) do
        return false
    end
    return true
end

local function resolve_refs(t, ref_spec)
    local m = require("match")
    local V = m.namespace().vars
    local matched_refs, captured_refs = 
            m.match_all({ [V.ref_var] = {[ref_spec.tag] = V.pattern(m.is_table) } }, t)

    local old_refs = {}

    local function restore_old_refs()
        for i, ref in ipairs(old_refs) do
            matched_refs[i][captured_refs[i].ref_var] = ref
        end
    end

    for i, vars in ipairs(captured_refs) do
        local matched_ref = matched_refs[i]
        local old_ref = matched_ref[vars.ref_var]
        table.insert(old_refs, old_ref)
        matched_ref[vars.ref_var] = nil -- remove the reference itself

        local ref_on_missing_fn = vars.pattern.on_missing
        local ref_on_duplicate_fn = vars.pattern.on_duplicate
        vars.pattern.on_missing = nil
        vars.pattern.on_duplicate = nil
        local elements = m.match_all(vars.pattern, t)
        if #elements > 1 then
            local dup_fn = ref_on_duplicate_fn or ref_spec.on_duplicate
            assert(type(dup_fn) == "function", "ref on_duplicate is not a function")
            restore_old_refs()
            vars.pattern.on_duplicate = ref_on_duplicate_fn
            dup_fn(vars.pattern)
            return nil
        elseif #elements == 0 then
            local missing_fn = ref_on_missing_fn or ref_spec.on_missing
            assert(type(missing_fn) == "function", "ref on_missing is not a function: " .. simple_table_to_string(matched_ref) )
            restore_old_refs()
            vars.pattern.on_missing = ref_on_missing_fn
            missing_fn(vars.pattern)
            return nil
        end

        local element = elements[1]

        matched_ref[vars.ref_var] = element
    end
    return t
end

local function default_on_missing(ref_spec)
    error("could not find reference " .. simple_table_to_string(ref_spec))
end

local function default_on_duplicate(ref_spec)
    error("found multiple matching elements for reference " .. simple_table_to_string(ref_spec))
end

local function new_blaze(config)
    config = config or {}

    if config.ref then
        assert(config.ref.tag, "A tag key must be provided to lookup references. Like tag='ref'")
        config.ref.on_missing = config.ref.on_missing or default_on_missing
        config.ref.on_duplicate = config.ref.on_duplicate or default_on_duplicate

        assert(type(config.ref.on_missing) == "function", "reference config for on_missing must be a function (takes a ref-spec)")
        assert(type(config.ref.on_missing) == "function", "reference config for on_missing must be a function (takes a ref-spec)")
    end

    -- nil gets defaulted and false is for not including it in metatable
    local key_alias = config.key_alias 
                      or config.key_alias == nil and "key" 
    local parent_alias = config.parent_alias 
                         or config.parent_alias == nil and "parent" 
    local children_alias = config.children_alias 
                           or config.children_alias == nil and "children" 
    local root_alias = config.root_key_alias 
                        or config.root_key_alias == nil and "root"
    local next_alias = config.next_alias 
                        or config.next_alias == nil and "next"
    local prev_alias = config.prev_alias 
                        or config.prev_alias == nil and "prev"
    local first_alias = config.first_alias 
                        or config.first_alias == nil and "first"
    local last_alias = config.last_alias 
                        or config.last_alias == nil and "last"

    local ownership = config.ownership or {}
    local id_tags = config.id_tags or {}

    local plurals = {}
    for owned, owner in pairs(ownership) do
        plurals[owner] = owned
    end

    local reserved_keys = {}
    if key_alias then reserved_keys[key_alias] = true end
    if parent_alias then reserved_keys[parent_alias] = true end
    if children_alias then reserved_keys[children_alias] = true end

    local function is_plural_ancestor(parent)
        while parent do
            if plurals[parent.key] then
                return true
            end
            parent = parent.parent
        end
        return false
    end

    local function blaze(t, key, parent)
        assert(type(t) == "table")

        if config.ref then
            if not resolve_refs(t, config.ref) then
                return nil
            end
        end

        local marked = {}

        local function blaze_index(t, key, parent)
            local owner = ownership[key]
            if not marked[t] and (not parent 
                    or owner and parent[owner] 
                    or is_empty(plurals) and is_empty(ownership)
                    or type(key) == "number" and is_plural_ancestor(parent)
                    or type(key) ~= "number" and not owner) then
                key = key or root_alias
                local old_mt = getmetatable(t)

                local mt = {
                    marked = marked,
                    old_mt = old_mt,
                    color = config.color,
                    __index = {}
                }
                if root_alias then
                    if parent then
                        mt.__index[root_alias] = parent[root_alias]
                    else
                        mt.__index[root_alias] = t
                    end
                end
                if key_alias and type(key) == "string" then
                    mt.__index[key_alias] = key
                end
                if key_alias and type(key) == "number" then -- arrays {{{
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
                    local id_tag = id_tags[parent.key] 
                    if id_tag then
                        local name = rawget(t, id_tag)
                        assert(name, "No id_tag " .. id_tag 
                                      .. " for element #" .. key .. " of " .. parent.key)
                        local parent_mt = getmetatable(parent)
                        assert(parent_mt.marked, "Parent hasn't been marked. This should not happen")
                        assert(not rawget(parent_mt.__index, name), "Duplicated name " .. name .. " in array element #" .. key .. " for " .. parent.key)
                        parent_mt.__index[name] = t
                    end
                    -- optional default global tags
                    for _, id_tag in ipairs(id_tags) do
                        if id_tag then
                            local name = rawget(t, id_tag)
                            if name then
                                local parent_mt = getmetatable(parent)
                                assert(parent_mt.marked, "Parent hasn't been marked. This should not happen")
                                assert(not rawget(parent_mt.__index, name), "Duplicated name " .. name .. " in array element #" .. key .. " for " .. parent.key)
                                parent_mt.__index[name] = t
                            end
                        end
                    end

                    local prev_index = key - 1
                    local prev_element = rawget(parent, prev_index) 
                    if prev_element then
                        local prev_mt = getmetatable(prev_element)
                        if prev_mt then
                            prev_mt.__index[next_alias] = t
                            mt.__index[prev_alias] = prev_element
                        end
                    end
                end     -- }}}
                if parent_alias then
                    mt.__index[parent_alias] = parent
                end
                if children_alias then
                    mt.__index[children_alias] = {}
                end
                if t[1] then    -- is array with at least one element?
                    mt.__index[first_alias] = t[1]
                    mt.__index[last_alias] = t[#t]
                end
                setmetatable(t, mt)
                if parent then
                    local mt_mt = {
                        __index = function(t, k)
                            local p = t
                            while p and p[key_alias] ~= k do
                                p = p[parent_alias]
                            end
                            if not p and mt.old_mt then
                                if type(mt.old_mt.__index) == "table" then
                                    return mt.old_mt.__index[k]
                                elseif type(mt.old_mt.__index) == "function" then
                                    return mt.old_mt.__index(t, k)
                                else
                                    error("invalid type for mt.__index: " 
                                            .. type(mt.old_mt.__index))
                                end
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

        local seen = {}

        local function recursive_blaze(t, key, parent)
            -- TODO: this two-level seen does not work for all cases
            -- (ie. three-or-more-level-similar paths on different branches)
            -- come up with a real algorithm that solves the problem of delay
            -- marking vs circular references
            if not seen[t] or not seen[t][parent or "root"] then
                seen[t] = seen[t] or {}
                seen[t][parent or "root"] = true

                blaze_index(t, key, parent)

                -- insert first the array elements
                local len = 0
                for i,v in ipairs(t) do
                    len = len + 1
                    if type(v) == "table" then
                        recursive_blaze(v, i, t)
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
                        error("Key '" .. k .. "' clashes with blaze key, in element '" 
                                .. key .. "'. Use constructor to override blaze words/keys")
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
                    recursive_blaze(v, k, t)
                    if children_alias and t[children_alias] then
                        table.insert(t[children_alias], v)
                    end
                end
            end

            return t
        end

        return recursive_blaze(t, root_alias)
    end

    local function deblaze(t)
        local mt = getmetatable(t)
        assert(mt.marked, "Not a blazed table")
        for v, _ in pairs(mt.marked) do
            local mt = getmetatable(v)
            local old_mt = mt.old_mt
            setmetatable(v, old_mt)
        end

        return t
    end

    return blaze, deblaze
end

return new_blaze
