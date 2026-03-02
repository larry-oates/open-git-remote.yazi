return {
    entry = function()
        local function safe_notify(title, content)
            if (type(ya) == "table" or type(ya) == "userdata") and type(ya.notify) == "function" then
                ya.notify {
                    title = title,
                    content = content,
                    timeout = 0,
                    urgency = 1,
                    progress = 0,
                    id = 0
                }
            end
            if package.config:sub(1, 1) == "\\" then
                local esc_c = tostring(content):gsub('"', '\\"')
                local esc_t = tostring(title):gsub('"', '\\"')
                local cmd =
                    'powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show(\\"' ..
                        esc_c .. '\\",\\"' .. esc_t .. '\\")"'
                os.execute(cmd)
            else
                local function has_cmd(cmd)
                    local p = io.popen("command -v " .. cmd .. " 2>/dev/null")
                    local out = p and p:read("*a") or ""
                    if p then
                        p:close()
                    end
                    return out ~= nil and out ~= ""
                end

                local function shell_escape(s)
                    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
                end

                if has_cmd("notify-send") then
                    local cmd = "notify-send " .. shell_escape(title) .. " " .. shell_escape(content) ..
                                    " >/dev/null 2>&1 &"
                    os.execute(cmd)
                elseif has_cmd("zenity") then
                    local cmd =
                        "zenity --info --title " .. shell_escape(title) .. " --text " .. shell_escape(content) ..
                            " >/dev/null 2>&1 &"
                    os.execute(cmd)
                elseif has_cmd("kdialog") then
                    local cmd = "kdialog --title " .. shell_escape(title) .. " --msgbox " .. shell_escape(content) ..
                                    " >/dev/null 2>&1 &"
                    os.execute(cmd)
                else
                    io.stderr:write(tostring(title) .. ": " .. tostring(content) .. "\n")
                end
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
                table.insert(cands, {
                    on = tostring(i),
                    desc = v
                })
            end

            local idx = ya.which({
                cands = cands,
                silent = false
            })
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
            url = url:gsub("^git@ssh%.dev%.azure%.com:v3/([^/]+)/([^/]+)/([^/]+)$",
                "https://dev.azure.com/%1/%2/_git/%3")
        elseif url:match("^ssh://git@ssh%.dev%.azure%.com.-/v3/") then
            url = url:gsub("^ssh://git@ssh%.dev%.azure%.com.-/v3/([^/]+)/([^/]+)/([^/]+)$",
                "https://dev.azure.com/%1/%2/_git/%3")
        elseif url:match("^git@vs%-ssh%.visualstudio%.com:v3/") then
            url = url:gsub("^git@vs%-ssh%.visualstudio%.com:v3/([^/]+)/([^/]+)/([^/]+)$",
                "https://dev.azure.com/%1/%2/_git/%3")
        elseif url:match("^ssh://git@vs%-ssh%.visualstudio%.com.-/v3/") then
            url = url:gsub("^ssh://git@vs%-ssh%.visualstudio%.com.-/v3/([^/]+)/([^/]+)/([^/]+)$",
                "https://dev.azure.com/%1/%2/_git/%3")
        end

        local function transform_bitbucket(url)
			-- ssh form: git@host:project/repo(.git)
			local host, project, repo = url:match("^git@([^:]+):([^/]+)/([^%.]+)%.git$")
			if host then
				return "https://" .. host .. "/projects/" .. project .. "/repos/" .. repo .. "/browse"
			end

			-- https form: https://host/scm/project/repo(.git)
			host, project, repo = url:match("^https?://([^/]+)/scm/([^/]+)/([^%.]+)")
			if host then
				return "https://" .. host .. "/projects/" .. project .. "/repos/" .. repo .. "/browse"
			end

			-- ssh with protocol (with or without port)
			host, project, repo = url:match("^ssh://git@([^/]+)/([^/]+)/([^%.]+)%.git$")
			if host then
				return "https://" .. host .. "/projects/" .. project .. "/repos/" .. repo .. "/browse"
			end

			return nil
		end



        -- check bitbucket transformations first
        local bb = transform_bitbucket(url)
        if bb then
            url = bb
            -- Standard Git fallbacks
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
            os.execute("start " .. url)
        else
            -- Unix (macOS, Linux, WSL)
            local function has_cmd(cmd)
                local p = io.popen("command -v " .. cmd .. " 2>/dev/null")
                local out = p and p:read("*a") or ""
                if p then
                    p:close()
                end
                return out ~= nil and out ~= ""
            end

            local opener
            if has_cmd("open") then
                opener = "open"
            elseif has_cmd("xdg-open") then
                opener = "xdg-open"
            elseif has_cmd("wslview") then
                opener = "wslview"
            end

            -- Additional browser fallbacks
            local fallbacks = {"gio", "sensible-browser", "x-www-browser", "firefox", "google-chrome", "chromium",
                               "brave-browser"}

            local function shell_escape(s)
                return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
            end

            local cmd
            if opener then
                cmd = opener .. " " .. shell_escape(url) .. " >/dev/null 2>&1 &"
            else
                for _, b in ipairs(fallbacks) do
                    if has_cmd(b) then
                        cmd = b .. " " .. shell_escape(url) .. " >/dev/null 2>&1 &"
                        break
                    end
                end
            end

            if cmd then
                local ok = os.execute(cmd)
                if not ok then
                    pcall(safe_notify, "Git Open", "Failed to open URL with command: " .. cmd)
                end
            else
                safe_notify("Git Open", "No browser opener found (install xdg-utils or a browser)")
            end
        end
    end
}
