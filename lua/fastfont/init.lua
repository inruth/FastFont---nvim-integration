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
	elseif term and term:lower() == "wezterm" then
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
	
	-- Setup command for terminal configuration
	vim.api.nvim_create_user_command("FastFontSetupTerm", function()
		local term = os.getenv("TERM_PROGRAM")

		if term and term:lower() == "wezterm" then
			local wez_path = vim.fn.expand("~/.wezterm.lua")
			-- 1. Check if it's already installed
			local f_read = io.open(wez_path, "r")
			local content = f_read and f_read:read("*a") or ""
			if f_read then f_read:close() end

			if content:find("FastFontMode") then
				vim.notify("FastFont: Hook is already installed in wezterm.lua", vim.log.levels.INFO)
				return
			end

			-- 2. Append the hook if not found
			local f_write = io.open(wez_path, "a")
			if f_write then
				local hook = [[

-- [FastFont.nvim Auto-Generated Hook]
wezterm.on('user-var-changed', function(window, pane, name, value)
	if name == 'FastFontMode' then
		local overrides = window:get_config_overrides() or {}
		if value ~= 'coding' and value ~= '' then
			overrides.font = wezterm.font(value)
		else
			overrides.font = nil 
		end
		window:set_config_overrides(overrides)
	end
end)
]]
				f_write:write(hook)
				f_write:close()
				vim.notify("FastFont: Hook successfully added! Please restart WezTerm.", vim.log.levels.INFO)
			else
				vim.notify("FastFont: Could not open ~/.wezterm.lua for writing", vim.log.levels.ERROR)
			end

		elseif term == "kitty" then
			local kitty_path = vim.fn.expand("~/.config/kitty/kitty.conf")
			local f = io.open(kitty_path, "a")
			if f then
				f:write("\n# [FastFont.nvim] Allow font switching\nallow_remote_control yes\n")
				f:close()
				vim.notify("FastFont: Remote control enabled in kitty.conf. Please restart Kitty.", vim.log.levels.INFO)
			else
				vim.notify("FastFont: Could not open kitty.conf", vim.log.levels.ERROR)
			end
		else
			vim.notify("FastFont: Your terminal (" .. tostring(term) .. ") requires manual font setup.", vim.log.levels.WARN)
		end
	end, { desc = "Injects required terminal hooks for FastFont" })

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
