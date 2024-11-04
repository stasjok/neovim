--
-- Tests for default autocmds, mappings, commands, and menus.
--
-- See options/defaults_spec.lua for default options and environment decisions.
--

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

describe('default', function()
  describe('key mappings', function()
    describe('unimpaired-style mappings', function()
      it('do not show a full stack trace #30625', function()
        n.clear({ args_rm = { '--cmd' } })
        local screen = Screen.new(40, 8)
        screen:attach()
        screen:set_default_attr_ids({
          [1] = { foreground = Screen.colors.NvimDarkGray4 },
          [2] = {
            background = Screen.colors.NvimLightGrey3,
            foreground = Screen.colors.NvimDarkGray3,
          },
          [3] = { foreground = Screen.colors.NvimLightRed },
          [4] = { foreground = Screen.colors.NvimLightCyan },
        })

        n.feed('[a')
        screen:expect({
          grid = [[
                                                    |
            {1:~                                       }|*4
            {2:                                        }|
            {3:E163: There is only one file to edit}    |
            {4:Press ENTER or type command to continue}^ |
          ]],
        })

        n.feed('[q')
        screen:expect({
          grid = [[
            ^                                        |
            {1:~                                       }|*5
            {2:[No Name]             0,0-1          All}|
            {3:E42: No Errors}                          |
          ]],
        })

        n.feed('[l')
        screen:expect({
          grid = [[
            ^                                        |
            {1:~                                       }|*5
            {2:[No Name]             0,0-1          All}|
            {3:E776: No location list}                  |
          ]],
        })

        n.feed('[t')
        screen:expect({
          grid = [[
            ^                                        |
            {1:~                                       }|*5
            {2:[No Name]             0,0-1          All}|
            {3:E73: Tag stack empty}                    |
          ]],
        })
      end)

      describe('[<Space>', function()
        it('adds an empty line above the current line', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed('[<Space>')
          n.expect([[

          first line]])
        end)

        it('works with a count', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed('5[<Space>')
          n.expect([[





          first line]])
        end)
      end)

      describe(']<Space>', function()
        it('adds an empty line below the current line', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed(']<Space>')
          n.expect([[
          first line
          ]])
        end)

        it('works with a count', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed('5]<Space>')
          n.expect([[
          first line




          ]])
        end)
      end)
    end)
  end)
end)
