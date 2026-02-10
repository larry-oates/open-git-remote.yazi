return {
	entry = function()
		-- 1. Get remotes using Yazi's async Command API
		local output, err = Command("git"):arg("remote"):output()

		if not output then
			return ya.notify({ title = "Git Open", content = "Failed to run git: " .. tostring(err), level = "error" })
		end

		local remotes = {}
		for line in output.stdout:gmatch("[^\r\n]+") do
			table.insert(remotes, line)
		end

		if #remotes == 0 then
			return ya.notify({ title = "Git Open", content = "No remotes found", level = "warn" })
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

		-- 3. Execute the opener with a more robust shell string
		-- We wrap the URL in quotes to prevent shell injection/parsing issues
		ya.emit("shell", {
			block = false,
			confirm = false,
			[[
                remote_url=$(git remote get-url ]] .. selected_remote .. [[)
                # Improved sed logic to handle common git URL formats
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
