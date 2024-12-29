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
    describe('Visual mode search mappings', function()
      it('handle various chars properly', function()
        n.clear({ args_rm = { '--cmd' } })
        local screen = Screen.new(60, 8)
        screen:attach()
        screen:set_default_attr_ids({
          [1] = { foreground = Screen.colors.NvimDarkGray4 },
          [2] = {
            foreground = Screen.colors.NvimDarkGray3,
            background = Screen.colors.NvimLightGray3,
          },
          [3] = {
            foreground = Screen.colors.NvimLightGrey1,
            background = Screen.colors.NvimDarkYellow,
          },
          [4] = {
            foreground = Screen.colors.NvimDarkGrey1,
            background = Screen.colors.NvimLightYellow,
          },
        })
        n.api.nvim_buf_set_lines(0, 0, -1, true, {
          [[testing <CR> /?\!1]],
          [[testing <CR> /?\!2]],
          [[testing <CR> /?\!3]],
          [[testing <CR> /?\!4]],
        })
        n.feed('gg0vf!o*')
        screen:expect([[
          {3:testing <CR> /?\!}1                                          |
          {4:^testing <CR> /?\!}2                                          |
          {3:testing <CR> /?\!}3                                          |
          {3:testing <CR> /?\!}4                                          |
          {1:~                                                           }|*2
          {2:[No Name] [+]                             2,1            All}|
          /\Vtesting <CR> \/?\\!                    [2/4]             |
        ]])
        n.feed('n')
        screen:expect([[
          {3:testing <CR> /?\!}1                                          |
          {3:testing <CR> /?\!}2                                          |
          {4:^testing <CR> /?\!}3                                          |
          {3:testing <CR> /?\!}4                                          |
          {1:~                                                           }|*2
          {2:[No Name] [+]                             3,1            All}|
          /\Vtesting <CR> \/?\\!                    [3/4]             |
        ]])
        n.feed('G0vf!o#')
        screen:expect([[
          {3:testing <CR> /?\!}1                                          |
          {3:testing <CR> /?\!}2                                          |
          {4:^testing <CR> /?\!}3                                          |
          {3:testing <CR> /?\!}4                                          |
          {1:~                                                           }|*2
          {2:[No Name] [+]                             3,1            All}|
          ?\Vtesting <CR> /?\\!                     [3/4]             |
        ]])
        n.feed('n')
        screen:expect([[
          {3:testing <CR> /?\!}1                                          |
          {4:^testing <CR> /?\!}2                                          |
          {3:testing <CR> /?\!}3                                          |
          {3:testing <CR> /?\!}4                                          |
          {1:~                                                           }|*2
          {2:[No Name] [+]                             2,1            All}|
          ?\Vtesting <CR> /?\\!                     [2/4]             |
        ]])
      end)
    end)

    describe('unimpaired-style mappings', function()
      it('show the command ouptut when successful', function()
        n.clear({ args_rm = { '--cmd' } })
        local screen = Screen.new(40, 8)
        n.fn.setqflist({
          { filename = 'file1', text = 'item1' },
          { filename = 'file2', text = 'item2' },
        })

        n.feed(']q')

        screen:set_default_attr_ids({
          [1] = { foreground = Screen.colors.NvimDarkGrey4 },
          [2] = {
            background = Screen.colors.NvimLightGray3,
            foreground = Screen.colors.NvimDarkGrey3,
          },
        })
        screen:expect({
          grid = [[
            ^                                        |
            {1:~                                       }|*5
            {2:file2                 0,0-1          All}|
            (2 of 2): item2                         |
          ]],
        })
      end)

      it('do not show a full stack trace when unsuccessful #30625', function()
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

        it('supports dot repetition', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed('[<Space>')
          n.feed('.')
          n.expect([[


          first line]])
        end)

        it('supports dot repetition and a count', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed('[<Space>')
          n.feed('3.')
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

        it('supports dot repetition', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed(']<Space>')
          n.feed('.')
          n.expect([[
          first line

          ]])
        end)

        it('supports dot repetition and a count', function()
          n.clear({ args_rm = { '--cmd' } })
          n.insert([[first line]])
          n.feed(']<Space>')
          n.feed('2.')
          n.expect([[
          first line


          ]])
        end)
      end)
    end)
  end)
end)
