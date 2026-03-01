return {
	entry = function()
		local function safe_notify(title, content)
			if type(ya) == "table" and type(ya.notify) == "function" then
				pcall(ya.notify, { title = title, content = content })
			end
			if package.config:sub(1,1) == "\\" then
				local esc_c = tostring(content):gsub('"', '\\"')
				local esc_t = tostring(title):gsub('"', '\\"')
				local cmd = 'powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show(\\"' .. esc_c .. '\\",\\"' .. esc_t .. '\\")"'
				os.execute(cmd)
			end
		end
		-- 1. Get remotes using Yazi's async Command API
		local output, err = Command("git"):arg("remote"):output()

		if not output then
			safe_notify("Git Open", "Failed to run git: " .. tostring(err))
			return
		end

		local remotes = {}
		for line in output.stdout:gmatch("[^\r\n]+") do
			table.insert(remotes, line)
		end

		if #remotes == 0 then
			safe_notify("Git Open", "No remotes found")
			return
		end

		-- 2. Select remote
		local selected_remote
		if #remotes == 1 then
			selected_remote = remotes[1]
		else
			local cands = {}
			for i, v in ipairs(remotes) do
				table.insert(cands, { on = tostring(i), desc = v })
			end

			local idx = ya.which({ cands = cands, silent = false })
			if not idx then
				return
			end
			selected_remote = remotes[idx]
		end

		-- 3. Get remote URL
		local output_url, err_url = Command("git"):arg("remote"):arg("get-url"):arg(selected_remote):output()
		if not output_url then
			safe_notify("Git Open", "Failed to get remote url: " .. tostring(err_url))
			return
		end
		local url = output_url.stdout:gsub("[\r\n]+$", "")

		if not url or url == "" then
			safe_notify("Git Open", "Empty remote URL")
			return
		end

		-- 4. Transform URL (Lua implementation of the sed logic)
		-- Azure DevOps
		if url:match("^git@ssh%.dev%.azure%.com:v3/") then
			url = url:gsub("^git@ssh%.dev%.azure%.com:v3/([^/]+)/([^/]+)/([^/]+)$", "https://dev.azure.com/%1/%2/_git/%3")
		elseif url:match("^ssh://git@ssh%.dev%.azure%.com.-/v3/") then
			url = url:gsub("^ssh://git@ssh%.dev%.azure%.com.-/v3/([^/]+)/([^/]+)/([^/]+)$", "https://dev.azure.com/%1/%2/_git/%3")
		elseif url:match("^git@vs%-ssh%.visualstudio%.com:v3/") then
			url = url:gsub("^git@vs%-ssh%.visualstudio%.com:v3/([^/]+)/([^/]+)/([^/]+)$", "https://dev.azure.com/%1/%2/_git/%3")
		elseif url:match("^ssh://git@vs%-ssh%.visualstudio%.com.-/v3/") then
			url = url:gsub("^ssh://git@vs%-ssh%.visualstudio%.com.-/v3/([^/]+)/([^/]+)/([^/]+)$", "https://dev.azure.com/%1/%2/_git/%3")
		-- Standard Git
		elseif url:match("^git@[^:]+:") then
			url = url:gsub("^git@([^:]+):(.+)$", "https://%1/%2")
		elseif url:match("^ssh://git@") then
			url = url:gsub("^ssh://git@([^/]+)/(.+)$", "https://%1/%2")
		end

		-- Clean up
		url = url:gsub("%.git$", "")
		url = url:gsub("^https:///", "https://")

		if not url or url == "" then
			safe_notify("Git Open", "Failed to transform URL")
			return
		end

		-- 5. Open URL
		if package.config:sub(1, 1) == "\\" then
			-- Windows
			os.execute('start ' .. url)
		else
			-- Unix (macOS, Linux, WSL)
			ya.emit("shell", string.format([[
				if command -v open >/dev/null 2>&1; then open "%s"
				elif command -v xdg-open >/dev/null 2>&1; then xdg-open "%s"
				elif command -v wslview >/dev/null 2>&1; then wslview "%s"
				else echo "No browser opener found"
				fi
			]], url, url, url))
		end
	end,
}
