-- Configurable threshold for using fzf
local opts = {
	fzf_threshold = 5, -- >= this uses fzf, otherwise Which-Key
}

return {
	entry = function()
		-- 1️⃣ Get git remotes
		local output, err = Command("git"):arg("remote"):output()
		if not output then
			return ya.notify({
				title = "Git Open",
				content = "Failed to run git: " .. tostring(err),
				level = "error",
			})
		end

		-- 2️⃣ Parse remotes
		local remotes = {}
		for line in output.stdout:gmatch("[^\r\n]+") do
			table.insert(remotes, line)
		end

		if #remotes == 0 then
			return ya.notify({
				title = "Git Open",
				content = "No remotes found",
				level = "warn",
			})
		end

		local selected_remote

		-- 3️⃣ Single remote → auto-select
		if #remotes == 1 then
			selected_remote = remotes[1]

		-- 4️⃣ Many remotes → fzf via shell
		elseif #remotes > opts.fzf_threshold then
			-- Create a safe temporary file
			local tmpfile = os.tmpname()

			-- Build the fzf command
			local cmd = "git remote | fzf --height=40% --layout=reverse --border > " .. tmpfile

			-- Run fzf in a real terminal
			ya.emit("shell", {
				block = true,
				confirm = false,
				cmd,
			})

			-- Read the selected remote from the temp file
			local f = io.open(tmpfile, "r")
			if f then
				selected_remote = f:read("*l")
				f:close()
			end

			-- Delete the temp file immediately
			os.remove(tmpfile)

			if not selected_remote or selected_remote == "" then
				return ya.notify({
					title = "Git Open",
					content = "No selection made",
					level = "warn",
				})
			end

		-- 5️⃣ Few remotes → Which-Key
		else
			local cands = {}
			for i, remote in ipairs(remotes) do
				table.insert(cands, { on = tostring(i), desc = remote })
			end

			local idx = ya.which({ cands = cands, silent = false })
			if not idx then
				return
			end
			selected_remote = remotes[idx]
		end

		-- 6️⃣ Notify user of selection
		ya.notify({
			title = "Git Open",
			content = "Opening remote: " .. selected_remote,
			timeout = 3,
		})

		-- 7️⃣ Open remote URL in browser
		ya.emit("shell", {
			block = false,
			confirm = false,
			[[
                remote_url=$(git remote get-url ]] .. selected_remote .. [[)
                browser_url=$(echo "$remote_url" | sed -E \
                    -e 's|git@([^:]+):(.+)|https://\1/\2|' \
                    -e 's|ssh://git@([^/]+)/(.+)|https://\1/\2|' \
                    -e 's|\.git$||' \
                    -e 's|https:///|https://|')

                if command -v open >/dev/null 2>&1; then open "$browser_url"
                elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$browser_url"
                elif command -v wslview >/dev/null 2>&1; then wslview "$browser_url"
                fi
            ]],
		})
	end,
}
