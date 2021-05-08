local telescope = require('telescope')
local utils = require('telescope.utils')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')

local function get_sessions(format)
    return utils.get_os_command_output({ 'tmux', 'list-sessions', '-F', format })
end

local function get_tmux_windows(format)
    local sessions = utils.get_os_command_output({ 'tmux', 'list-windows', '-F', format })
    return sessions
end


local sessions = function(opts)
    local session_names = get_sessions('#S')
    local user_formatted_session_names = get_sessions(opts.format or '#S')
    local formatted_to_real_session_map = {}
    for i, v in ipairs(user_formatted_session_names) do
        formatted_to_real_session_map[v] = session_names[i]
    end

    -- FIXME: This command can display a session name even if you are in a seperate terminal session that isn't using tmux
    local current_session = utils.get_os_command_output({'tmux', 'display-message', '-p', '#S'})[1]

    pickers.new(opts, {
        prompt_title = 'Tmux Sessions',
        finder = finders.new_table {
            results = user_formatted_session_names
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        previewer = previewers.new_buffer_previewer({
            define_preview = function(self, entry, status)
                local session_name = formatted_to_real_session_map[entry[1]]
                -- Can't attach to current session otherwise neovim will freak out
                if current_session == session_name then
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {"Currently attached to this session."})
                else
                    vim.api.nvim_buf_call(self.state.bufnr, function()
                        vim.fn.termopen(string.format("tmux attach -t %s", session_name))
                    end)
                end
            end
        }),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                vim.api.nvim_command('silent !tmux switchc -t ' .. selection.value)
            end)

            return true
        end,
    }):find()
end

return telescope.register_extension {
    exports = {
        sessions = sessions
    }
}
