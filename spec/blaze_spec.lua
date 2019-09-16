describe("blaze", function()
    describe("behavior", function()
        local blaze = require("blaze")()

        it("marks up an empty table", function()
            local t = {}
            blaze(t)

            assert.is.equal("root", t.key)
            assert.is.equal("root", t.root.key)
            assert.is.truthy(t.children)
            assert.is.falsy(t.parent)
            assert(0, #t.children)
        end)

        it("can mark circular tables", function()
            local t = { }
            local a = { a = t }
            t.a = a

            blaze(t)
            assert.is.equal("a", t.a.key)
            assert.is.equal("root", t.key)
        end)
        describe("a deeper table", function()
            local t = { a = { b = { c = 4 } } }
            blaze(t)

            it("tracks keys for table children", function()
                assert.is.equal("a", t.a.key)
                assert.is.equal("b", t.a.b.key)
            end)

            it("keeps track of children", function()
                assert.is.equal(1, #t.children)
                assert.is.equal(1, #t.a.children)
                -- only tables are considered children
                assert.is.equal(0, #t.a.b.children)

                assert.is.equal(t.a, t.children[1])
                assert.is.equal(t.a.b, t.children[1].children[1])
            end)

            it("keeps track of parent relationships", function()
                assert.is.equal(t, t.a.parent)
                assert.is.equal(t.a, t.a.b.parent)
                assert.is.equal(t.a.b, t.a.b.parent.b.parent.b)
                assert.is.equal(t, t.a.b.parent.parent)
            end)
            it("sets root access all across", function()
                assert.is.equal(t, t.a.b.root)
                assert.is.equal(t, t.a.root)
                assert.is.equal(t, t.root)
            end)

            it("does not affect original values/structure", function()
                assert.is.equal(4, t.a.b.c)
            end)

        end)
        describe("auto naming/key-by-name with id-tags", function()
            local blaze = require("blaze")(
                { id_tags = { A = "name" } })
            it("creates string keys for arrays when id_tags is provided for a type of parent", function()
                local t = { A = { 
                                  { name = "x", value = 1 },
                                  { name = "y", value = 2 },
                                },
                            B = {
                                  { name = "x", value = 1 },
                                  { name = "y", value = 2 },
                            }
                          }
                blaze(t)
                assert.is.equal(1, t.A.x.value)
                assert.is.equal(2, t.A.y.value)
                assert.is_nil(t.B.x)
                assert.is_nil(t.B.y)
            end)
            it("a general id-tag is used, when available", function()
                local blaze = require("blaze")(
                    { id_tags = { "id", A = "name" } })
                local t = { A = { 
                                  { name = "x", value = 1 },
                                  { name = "y", value = 2 },
                                },
                            B = {
                                  { id = "x", value = 1 },
                                  { id = "y", value = 2 },
                            },
                            C = {
                                  { other = "x", value = 1 },
                                  { other = "y", value = 2 },
                            }
                          }
                blaze(t)
                assert.is.equal(1, t.A.x.value)
                assert.is.equal(2, t.A.y.value)
                assert.is.equal(1, t.B.x.value)
                assert.is.equal(2, t.B.y.value)
                assert.is_nil(t.C.x)
                assert.is_nil(t.C.y)
            end)
            it("fails to tag if id-tag is missing", function()
                local t = { A = { 
                                  { name = "x", value = 1 },
                                  { bad_name = "y", value = 2 },
                                },
                          }
                assert.is.error(function() blaze(t) end, 
                    "No id_tag name for element #2 of A")
            end)
            it("fails to tag if the id-tag is not unique", function()
                local t = { A = { 
                                  { name = "x", value = 1 },
                                  { name = "x", value = 2 },
                                },
                          }
                assert.is.error(function() blaze(t) end, 
                    "Duplicated name x in array element #2 for A")
            end)
        end)
        describe("auto assigned back/upwards references", function()
            it("creates parent key reference in children", function()
                local t = { a = { b = { c = 4 } } }
                blaze(t)

                assert.is.equal(t.a, t.a.b.a)
            end)
            it("creates parent key reference in children across intermediate arrays", function()
                local t = { a = { array = {
                                    { b = 1 },
                                    { c = 2 }
                                    } } }
                blaze(t)

                assert.is.equal(t.a, t.a.array[1].a)
                assert.is_nil(rawget(t.a.array[1], "a"))
                assert.is.equal(t.a, t.a.array[2].a)

                assert.is.equal(t.a, t.a.array.a)
            end)
            it("uses the singular key for elements in an array", function()
                local blaze = require("blaze")(
                    { ownership = { part = "parts"} })
                local t = { a = { parts = {
                                    { b = 1 },
                                    { c = { d = { e = 2 } }, f = 3 }
                                    } } }
                blaze(t)
                assert.is.equal("part", t.a.parts[1].key)
                assert.is.equal(3, t.a.parts[2].c.d.part.f)
                assert.is.equal(2, #t.a.parts[2].c.d.parts)
            end)
            it("uses the singular key for elements in an multidimensional array", function()
                local blaze = require("blaze")(
                    { ownership = { element = "elements"} })
                local matrix = { elements = { 
                                    { { 1, 2, 3 }, { 4, 5, 6 } }
                                 }}
                blaze(matrix)
                assert.is.equal("element", matrix.elements[1][2].key)
                assert.is.equal(matrix, matrix.elements[1][2].root)
            end)
        end)
        describe("array blaze for next/prev navigation", function()
            it("add next and prev to array elements", function()
                local t = { A = { { a=1 }, { a=2 }, { a=3 } } }
                blaze(t)

                assert.is.equal(t.A[2], t.A[1].next)
                assert.is.equal(2, t.A[1].next.a)
                assert.is.equal(3, t.A[2].next.a)
                assert.is_nil(t.A[3].next)

                assert.is.equal(t.A[1], t.A[2].prev)
                assert.is.equal(2, t.A[3].prev.a)
                assert.is.equal(1, t.A[2].prev.a)
                assert.is_nil(t.A[1].prev)
            end)
        end)
        describe("table metatables", function()
            it("precedes other metatables with its metatable shadowing them", function()
                local t = {}
                local t_mt = { __index = { x = 5 } }
                setmetatable(t, t_mt)
                blaze(t)
                assert.is.equal("root", t.key)
                assert.is.equal(5, t.x)
            end)
        end)
        describe("element ownership", function()
            it("must specify single ownership in diamond relationships", function()
                local blaze = require("blaze")(
                    { ownership = { a = "A" } })

                local a = { }
                local t = {
                    A = { a = a },
                    B = { a = a },
                }
                blaze(t)
                assert.is.equal(t.A, t.A.a.parent)
                assert.is.equal(t.A, t.B.a.parent)
            end)
            it("can specify ownership with mixed/cross elements", function()
                local blaze = require("blaze")(
                    { ownership = { a = "A", b = "B"} })

                local a = { }
                local b = { }
                local t = {
                    A = { a = a, b = b },
                    B = { a = a, b = b },
                }
                blaze(t)
                assert.is.equal(t.A, t.A.a.parent)
                assert.is.equal(t.A, t.B.a.parent)
                assert.is.equal(t.B, t.B.b.parent)
                assert.is.equal(t.B, t.A.b.parent)
            end)
            it("can establish ownership in arrays", function()
                local blaze = require("blaze")(
                    { ownership = { b = "B"} })

                local x = { }
                local y = { }
                local t = { x, y, { A = { x, y } }, 
                                  { B = { x, y } }, 
                                  { C = { x, y } } }
                blaze(t)
                assert.is.equal(t[4].B, t[4].B[1].parent)
                assert.is.equal(t[4].B, t[4].B[2].parent)

                assert.is.equal(t[4].B, t[3].A[1].parent)
                assert.is.equal(t[4].B, t[3].A[2].parent)

                assert.is.equal(t[4].B, t[1].parent)
                assert.is.equal(t[4].B, t[2].parent)
            end)
        end)
        describe("resolution of references", function()
            -- explicit reference config in necessary
            -- otherwise no reference resolution is attempted
            local blaze = require("blaze")( { 
                    ref = { 
                        tag = "ref", 
                        on_missing = function(ref_element)
                            error("Could not find reference " .. ref_element.name)
                        end 
                    } 
            })
            it("resolves pending references in a tree to make it a circular tree/table", function()
                local t = { A = { a = { name = "one", other = 5 } },
                            B = { x = { ref = { name = "one" } } } }

                blaze(t)
                assert.is.equal(t.A.a, t.B.x)
                assert.is.equal(t.A, t.B.x.parent)
            end)
            it("does not resolve references when no ref config is given", function()
                local blaze = require("blaze")()
                local t = { A = { a = { name = "one", other = 5 } },
                            B = { x = { ref = { name = "one" } } } }

                blaze(t)
                assert.is.truthy(t.B.x.ref)
                assert.is.not_equal(t.A.a, t.B.x)
            end)
            it("calls on_missing given function when a reference is missing. Table is unchanged", function()
                local failed_ref
                local blaze = require("blaze"){
                    ref = {
                        tag = "ref",
                        on_missing = function(ref_element) 
                            failed_ref = ref_element.name
                        end
                    }

                }
                local t = { A = { a = { name = "one", other = 5 } },
                            B = { x = { ref = { name = "two" } } } }

                local res = blaze(t)
                assert.is.falsy(res)
                assert.is.equal("two", failed_ref)
                assert.is.equal("two", t.B.x.ref.name)
            end)
            it("calls on_duplicate given function when there is more than one match for a reference. Table is unchanged", function()
                local failed_ref
                local blaze = require("blaze"){
                    ref = {
                        tag = "ref",
                        on_duplicate = function(ref_element) 
                            failed_ref = ref_element.name
                        end
                    }

                }
                local t = { A = { a = { name = "one", other = 5 } },
                            A2 = { a = { name = "one", other = 3 } },
                            B = { x = { ref = { name = "one" } } } }

                local res = blaze(t)
                assert.is.falsy(res)
                assert.is.equal("one", failed_ref)
                assert.is.equal("one", t.B.x.ref.name)
            end)

            -- TODO: do we still want to locate all reference errors and 
            -- report them at once?
            it("calls on_missing function in the reference itself, when given", function()
                local failed_ref
                local on_missing = function(ref_element) 
                                        failed_ref = ref_element.name
                                    end

                local blaze = require("blaze"){ ref = { tag = "ref" } }
                local t = { A = { a = { name = "one", other = 5 } },
                            B = { x = { 
                                ref = { 
                                    name = "two",
                                    on_missing = on_missing
                          } } } }

                local res = blaze(t)
                assert.is.falsy(res)
                assert.is.equal("two", failed_ref)
                assert.is.equal("two", t.B.x.ref.name)
                assert.is.equal(on_missing, t.B.x.ref.on_missing)
            end)
            it("calls on_duplicate function in the reference itself, when given", function()
                local failed_ref
                local on_duplicate = function(ref_element) 
                                        failed_ref = ref_element.name
                                    end

                local blaze = require("blaze"){ ref = { tag = "ref" } }
                local t = { A = { a = { name = "one", other = 5 } },
                            A2 = { a = { name = "one", other = 3 } },
                            B = { x = { 
                                ref = { 
                                    name = "one",
                                    on_duplicate = on_duplicate
                          } } } }

                local res = blaze(t)
                assert.is.falsy(res)
                assert.is.equal("one", failed_ref)
                assert.is.equal("one", t.B.x.ref.name)
                assert.is.equal(on_duplicate, t.B.x.ref.on_duplicate)
            end)
            it("can configure the reference tag/name other than ref", function()
                local blaze = require("blaze"){ ref = { tag = "link" } }
                local t = { A = { a = { name = "one", other = 5 } },
                            B = { x = { link = { name = "one" } } } }

                blaze(t)
                assert.is.equal(t.A.a, t.B.x)
                assert.is.equal(t.A, t.B.x.parent)
            end)
        end)
        describe("children sorting", function()
            local t = {
                { a = 1 },
                { b = 2 },
                { c = 3 },
                z = { "z" },
                x = { "x" },
                y = { "y" },
            }
            blaze(t)

            it("puts children in array, from array first, then from table ", function()
                assert.is.equal(t[1], t.children[1])
                assert.is.equal(t[2], t.children[2])
                assert.is.equal(t[3], t.children[3])
                assert.is.equal(t.x, t.children[4])
                assert.is.equal(t.y, t.children[5])
                assert.is.equal(t.z, t.children[6])
            end)
        end)
        describe("function or table keys are not supported", function()
            it("errors out when the input table has a table key", function()
                local key_t = {}
                local t = { a = { [key_t] = { c = 4 } } }

                assert.is.error(function() blaze(t) end, 
                    "Invalid key of type table, in element 'a'")
            end)
            it("errors out when the input table has a function key", function()
                local key_fn = function() end
                local t = { [key_fn] = { b = { c = 4 } } }

                assert.is.error(function() blaze(t) end, 
                    "Invalid key of type function, in element 'root'")
            end)
        end)
    end)
    describe("name-clashing avoidance", function()
        describe("blaze aliasing", function()
            local blaze = require("blaze"){
                key_alias = "name",
                children_alias = "elements",
                parent_alias = "up",
                root_key_alias = "home",
                next_alias = "forward",
                prev_alias = "backward"
            }
            local t = { a = { b = { c = 4 } },
                        d = { {1}, {2}, {3} } }
            blaze(t)

            it("uses custom key accessor", function()
                assert.is.equal("b", t.a.b.name)
                assert.is.equal("home", t.name)
            end)
            it("uses custom parent accessor", function()
                assert.is.equal(t, t.a.up)
                assert.is.equal(t.a, t.a.b.up)
            end)
            it("uses custom children accessor", function()
                assert.is.equal(2, #t.elements)
                assert.is.equal(1, #t.a.elements)
                -- only tables are considered elements
                assert.is.equal(0, #t.a.b.elements)

                assert.is.equal(t.a, t.elements[1])
                assert.is.equal(t.a.b, t.elements[1].elements[1])
            end)
            it("uses custom next and prev accessors", function()
                assert.is.equal(t.d[2], t.d[1].forward)
                assert.is.equal(t.d[2], t.d[3].backward)
            end)
        end)
        it("errors when the original tree/table has a conflicting element", function()
            local blaze = require("blaze")()
            local t = { a = { key = { c = 4 } } }

            assert.is.error(function() blaze(t) end, 
                "Key 'key' clashes with blaze key, in element 'a'. Use constructor to override blaze words/keys")

            local t2 = { a = { b = { parent = 4 } } }

            assert.is.error(function() blaze(t2) end, 
                "Key 'parent' clashes with blaze key, in element 'b'. Use constructor to override blaze words/keys")
        end)
    end)
    describe("deblazing", function()
        it("returns a table to its original form after a deblaze", function()
            local t = { a = { b = 5 } }
            local mt = { __index = { x = 1, root = "old_root" } }

            setmetatable(t, mt)
            setmetatable(t.a, mt)
            assert.is.equal(1, t.x)
            assert.is.equal("old_root", t.root)
            assert.is.equal(mt, getmetatable(t))

            local blaze, deblaze = require("blaze")()
            blaze(t)

            assert.is_not.equal(mt, getmetatable(t))

            assert.is.equal(1, t.x)
            assert.is.equal("root", t.a.root.key)

            deblaze(t)

            assert.is.equal(1, t.x)
            assert.is.equal("old_root", t.root)
            assert.is.equal("old_root", t.a.root)

            assert.is.same({a={b=5}}, t)

            assert.is.equal(mt, getmetatable(t))
            assert.is.equal(mt, getmetatable(t.a))
        end)
    end)
    describe("multiple blazing", function()
        local t1 = { a = { b = 4 } }
        local t2 = { x = { y = 5 } }
        local T = { A = { B = t1 }, X = { Y = t2 } }

        local blaze1 = require("blaze"){
            children_alias = false,
            color = "blue"
        }
        blaze1(t1)
        assert.is.equal(t1, t1.a.root)

        local blaze2 = require("blaze"){
            root_key_alias = "doc",
            children_alias = false,
            color = "red"
        }
        blaze2(t2)

        local big_blaze = require("blaze"){
            root_key_alias = "top",
            parent_alias = "up",
            children_alias = false,
            color = "white"
        }

        big_blaze(T)

        it("preserves individual tree blazing for their respective roots", function()
            assert.is.equal(T, T.A.B.a.top)
            assert.is.equal(t1, T.A.B.a.root)
            assert.is.equal(t2, T.X.Y.x.doc)

            assert.is.equal(T, t1.a.top)
            assert.is.equal(T, t2.x.top)
        end)
        it("can have multiple synonyms for to parents", function()
            assert.is.equal(t1.a.parent, t1.a.up)
            assert.is_nil(t1.parent)
            assert.is.equal(T.A, t1.up)
            assert.is.equal("B", t1.key)
        end)
    end)
end)

