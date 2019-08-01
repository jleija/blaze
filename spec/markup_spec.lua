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
        describe("children sorting", function()
            local t = {
                x = { },
                { a = 1 },
                y = { },
                { b = 2 },
                z = { },
                { c = 3 },
            }
            markup(t)

            it("puts children in array, from array first, then from table ", function()
                assert.is.equal(t[1], t.children[1])
                assert.is.equal(t[2], t.children[2])
                assert.is.equal(t[3], t.children[3])
                assert.is.truthy(t.children[4])
                assert.is.truthy(t.children[5])
                assert.is.truthy(t.children[6])
                assert.is.falsy(t.children[7])
            end)
        end)
        describe("metatables not supported", function()
            local t = { a = { b = { c = 4 } } }
            local mt = { }
            setmetatable(t.a.b, mt)

            it("errors out when the input table has a metatable", function()
                assert.is.error(function() markup(t) end, "tables with metatables are not supported yet. In element 'b'")
            end)
        end)
    end)
    describe("name-clashing avoidance", function()
        describe("markup aliasing", function()
            local markup = require("markup"){
                key = "name",
                children = "elements",
                parent = "up",
                root_key = "home"
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

            assert.is.error(function() markup(t) end, "Key 'key' clashes with markup key, in element 'a'. Use constructor to override markup words/keys")

            local t2 = { a = { b = { parent = 4 } } }

            assert.is.error(function() markup(t2) end, "Key 'parent' clashes with markup key, in element 'b'. Use constructor to override markup words/keys")
        end)
    end)
end)

