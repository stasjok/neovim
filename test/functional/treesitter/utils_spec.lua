local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local insert = n.insert
local eq = t.eq
local exec_lua = n.exec_lua

before_each(clear)

describe('treesitter utils', function()
  before_each(clear)

  it('can find an ancestor', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
      root = tree:root()
      ancestor = assert(root:child(0))
      child = assert(ancestor:named_child(1))
      child_sibling = assert(ancestor:named_child(2))
      grandchild = assert(child:named_child(0))
    ]])

    eq(true, exec_lua('return vim.treesitter.is_ancestor(ancestor, child)'))
    eq(true, exec_lua('return vim.treesitter.is_ancestor(ancestor, grandchild)'))
    eq(false, exec_lua('return vim.treesitter.is_ancestor(child, ancestor)'))
    eq(false, exec_lua('return vim.treesitter.is_ancestor(child, child_sibling)'))
  end)

  it('can detect if a position is contained in a node', function()
    exec_lua([[
      node = {
        range = function()
          return 0, 4, 0, 8
        end,
      }
    ]])

    eq(false, exec_lua('return vim.treesitter.is_in_node_range(node, 0, 3)'))
    for i = 4, 7 do
      eq(true, exec_lua('return vim.treesitter.is_in_node_range(node, 0, ...)', i))
    end
    -- End column exclusive
    eq(false, exec_lua('return vim.treesitter.is_in_node_range(node, 0, 8)'))
  end)
end)
