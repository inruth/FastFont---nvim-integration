local M = {}

-- Define default configurations
local defaults = {
    filetypes = { "markdown", "text", "org" },
    reading_font = "Fast_Serif",
    coding_font = "JetBrainsMono Nerd Font",
    gui_reading_font = "Fast_Serif:h14",
    gui_coding_font = "JetBrainsMono Nerd Font:h12",
}

-- Base64 encoder for WezTerm user variables
local function b64_encode(data)
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function set_font_mode(is_reading, config)
    local term = os.getenv("TERM_PROGRAM")
    
    -- GUI Clients
    if vim.fn.has("gui_running") == 1 or vim.g.neovide then
        vim.opt.guifont = is_reading and config.gui_reading_font or config.gui_coding_font
    
    -- WezTerm
    elseif term == "WezTerm" then
        local val = is_reading and config.reading_font or config.coding_font
        io.stdout:write("\x1b]1337;SetUserVar=FastFontMode=" .. b64_encode(val) .. "\x07")
    
    -- Kitty
    elseif term == "kitty" then
        local font = is_reading and config.reading_font or config.coding_font
        os.execute("kitty @ set-font-family '" .. font .. "'")
    end
end

-- The setup function lazy.nvim will call
function M.setup(user_opts)
    -- Merge user options with defaults
    local config = vim.tbl_deep_extend("force", defaults, user_opts or {})
    
    local group = vim.api.nvim_create_augroup("FastFontToggle", { clear = true })

    vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
        group = group,
        callback = function()
            local ft = vim.bo.filetype
            local is_reading_file = false
            
            for _, v in ipairs(config.filetypes) do
                if ft == v then
                    is_reading_file = true
                    break
                end
            end
            
            set_font_mode(is_reading_file, config)
        end,
    })
end

return M
