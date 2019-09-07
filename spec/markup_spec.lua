describe("markup", function()
    describe("behavior", function()
        local markup = require("markup")()

        it("marks up an empty table", function()
            local t = {}
            markup(t)

            assert.is.equal("root", t.key)
            assert.is.truthy(t.children)
            assert.is.falsy(t.parent)
            assert(0, #t.children)
        end)

        it("can mark circular tables", function()
            local t = { }
            local a = { a = t }
            t.a = a

            markup(t)
            assert.is.equal("a", t.a.key)
            assert.is.equal("root", t.key)
        end)
        describe("a deeper table", function()
            local t = { a = { b = { c = 4 } } }
            markup(t)

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

            it("does not affect original values/structure", function()
                assert.is.equal(4, t.a.b.c)
            end)

        end)
        describe("auto naming/key-by-name with id-tags", function()
            pending("a general id-tag is used, when available", function()
            end)
            it("creates string keys for arrays when id_tags is provided for a type of parent", function()
                local markup = require("markup")(
                    { id_tags = { A = "name" } })
                local t = { A = { 
                                  { name = "x", value = 1 },
                                  { name = "y", value = 2 },
                                },
                            B = {
                                  { name = "x", value = 1 },
                                  { name = "y", value = 2 },
                            }
                          }
                markup(t)
                assert.is.equal(1, t.A.x.value)
                assert.is.equal(2, t.A.y.value)
                assert.is_nil(t.B.x)
                assert.is_nil(t.B.y)
            end)
            pending("fails to tag if id-tag is missing", function()
            end)
            pending("fails to tag if the id-tag is not unique", function()
            end)
        end)
        describe("auto assigned back/upwards references", function()
            it("creates parent key reference in children", function()
                local t = { a = { b = { c = 4 } } }
                markup(t)

                assert.is.equal(t.a, t.a.b.a)
            end)
            it("creates parent key reference in children across intermediate arrays", function()
                local t = { a = { array = {
                                    { b = 1 },
                                    { c = 2 }
                                    } } }
                markup(t)

                assert.is.equal(t.a, t.a.array[1].a)
                assert.is_nil(rawget(t.a.array[1], "a"))
                assert.is.equal(t.a, t.a.array[2].a)

                assert.is.equal(t.a, t.a.array.a)
            end)
            it("uses the singular key for elements in an array", function()
                local markup = require("markup")(
                    { ownership = { part = "parts"} })
                local t = { a = { parts = {
                                    { b = 1 },
                                    { c = { d = { e = 2 } }, f = 3 }
                                    } } }
                markup(t)
                assert.is.equal("part", t.a.parts[1].key)
                assert.is.equal(3, t.a.parts[2].c.d.part.f)
                assert.is.equal(2, #t.a.parts[2].c.d.parts)
            end)
            it("uses the singular key for elements in an multidimensional array", function()
                local markup = require("markup")(
                    { ownership = { element = "elements"} })
                local matrix = { elements = { 
                                    { { 1, 2, 3 }, { 4, 5, 6 } }
                                 }}
                markup(matrix)
                assert.is.equal("element", matrix.elements[1][2].key)
                assert.is.equal(matrix, matrix.elements[1][2].root)
            end)
        end)
        describe("table metatables", function()
            it("precedes other metatables with its metatable shadowing them", function()
                local t = {}
                local t_mt = { __index = { x = 5 } }
                setmetatable(t, t_mt)
                markup(t)
                assert.is.equal("root", t.key)
                assert.is.equal(5, t.x)
            end)
        end)
        describe("element ownership", function()
            it("must specify single ownership in diamond relationships", function()
                local markup = require("markup")(
                    { ownership = { a = "A" } })

                local a = { }
                local t = {
                    A = { a = a },
                    B = { a = a },
                }
                markup(t)
                assert.is.equal(t.A, t.A.a.parent)
                assert.is.equal(t.A, t.B.a.parent)
            end)
            it("can specify ownership with mixed/cross elements", function()
                local markup = require("markup")(
                    { ownership = { a = "A", b = "B"} })

                local a = { }
                local b = { }
                local t = {
                    A = { a = a, b = b },
                    B = { a = a, b = b },
                }
                markup(t)
                assert.is.equal(t.A, t.A.a.parent)
                assert.is.equal(t.A, t.B.a.parent)
                assert.is.equal(t.B, t.B.b.parent)
                assert.is.equal(t.B, t.A.b.parent)
            end)
            it("can establish ownership in arrays", function()
                local markup = require("markup")(
                    { ownership = { b = "B"} })

                local x = { }
                local y = { }
                local t = { x, y, { A = { x, y } }, 
                                  { B = { x, y } }, 
                                  { C = { x, y } } }
                markup(t)
                assert.is.equal(t[4].B, t[4].B[1].parent)
                assert.is.equal(t[4].B, t[4].B[2].parent)

                assert.is.equal(t[4].B, t[3].A[1].parent)
                assert.is.equal(t[4].B, t[3].A[2].parent)

                assert.is.equal(t[4].B, t[1].parent)
                assert.is.equal(t[4].B, t[2].parent)
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
            markup(t)

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

                assert.is.error(function() markup(t) end, 
                    "Invalid key of type table, in element 'a'")
            end)
            it("errors out when the input table has a function key", function()
                local key_fn = function() end
                local t = { [key_fn] = { b = { c = 4 } } }

                assert.is.error(function() markup(t) end, 
                    "Invalid key of type function, in element 'root'")
            end)
        end)
    end)
    describe("name-clashing avoidance", function()
        describe("markup aliasing", function()
            local markup = require("markup"){
                key_alias = "name",
                children_alias = "elements",
                parent_alias = "up",
                root_key_alias = "home"
            }
            local t = { a = { b = { c = 4 } } }
            markup(t)

            it("uses custom key accessor", function()
                assert.is.equal("b", t.a.b.name)
                assert.is.equal("home", t.name)
            end)
            it("uses custom parent accessor", function()
                assert.is.equal(t, t.a.up)
                assert.is.equal(t.a, t.a.b.up)
            end)
            it("uses custom children accessor", function()
                assert.is.equal(1, #t.elements)
                assert.is.equal(1, #t.a.elements)
                -- only tables are considered elements
                assert.is.equal(0, #t.a.b.elements)

                assert.is.equal(t.a, t.elements[1])
                assert.is.equal(t.a.b, t.elements[1].elements[1])
            end)
        end)
        it("errors when the original tree/table has a conflicting element", function()
            local markup = require("markup")()
            local t = { a = { key = { c = 4 } } }

            assert.is.error(function() markup(t) end, 
                "Key 'key' clashes with markup key, in element 'a'. Use constructor to override markup words/keys")

            local t2 = { a = { b = { parent = 4 } } }

            assert.is.error(function() markup(t2) end, 
                "Key 'parent' clashes with markup key, in element 'b'. Use constructor to override markup words/keys")
        end)
    end)
end)

