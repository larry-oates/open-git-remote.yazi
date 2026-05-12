local bitbucket_host_cache = {}
local bb_cache_loaded = false

-- Well-known public forges that are never Bitbucket Server — skip the REST API probe for these
local known_non_bitbucket = {
    ["github.com"]         = true,
    ["gitlab.com"]         = true,
    ["bitbucket.org"]      = true,
    ["dev.azure.com"]      = true,
    ["ssh.dev.azure.com"]  = true,
    ["vs-ssh.visualstudio.com"] = true,
    ["codeberg.org"]       = true,
    ["sourcehut.org"]      = true,
}

local function bb_cache_path()
    if package.config:sub(1, 1) == "\\" then
        local base = os.getenv("LOCALAPPDATA") or os.getenv("APPDATA") or ""
        return base .. "\\yazi\\open-git-remote-bb-hosts.txt"
    else
        local xdg = os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") or "") .. "/.cache"
        return xdg .. "/yazi/open-git-remote-bb-hosts.txt"
    end
end

local function load_bb_cache()
    if bb_cache_loaded then return end
    bb_cache_loaded = true
    local f = io.open(bb_cache_path(), "r")
    if not f then return end
    for line in f:lines() do
        local host = line:match("^%s*(.-)%s*$")
        if host ~= "" then bitbucket_host_cache[host] = true end
    end
    f:close()
end

local function persist_bb_host(host)
    local path = bb_cache_path()
    local dir = path:match("(.*[/\\])")
    if dir then
        if package.config:sub(1, 1) == "\\" then
            os.execute('mkdir "' .. dir .. '" 2>nul')
        else
            os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
        end
    end
    local f = io.open(path, "a")
    if f then f:write(host .. "\n"); f:close() end
end

local function transform_bitbucket(url, is_bitbucket_server)
    -- https form: https://host/scm/project/repo(.git)
    -- The /scm/ path prefix is unique to Bitbucket Server / Data Center
    local host, project, repo = url:match("^https?://([^/]+)/scm/([^/]+)/([^%.]+)")
    if host then
        return "https://" .. host .. "/projects/" .. project .. "/repos/" .. repo .. "/browse"
    end

    -- Personal repo ssh form: ssh://git@host/~username/repo.git
    -- The ~username prefix is unique to Bitbucket Server personal repositories
    host = url:match("^ssh://git@([^/:]+)/~")
    if host then
        local user, r = url:match("^ssh://git@[^/]+/~([^/]+)/([^%.]+)%.git$")
        if user then
            return "https://" .. host .. "/users/" .. user .. "/repos/" .. r .. "/browse"
        end
    end

    -- Personal repo git@ form: git@host:~username/repo.git
    host = url:match("^git@([^:]+):~")
    if host then
        local user, r = url:match("^git@[^:]+:~([^/]+)/([^%.]+)%.git$")
        if user then
            return "https://" .. host .. "/users/" .. user .. "/repos/" .. r .. "/browse"
        end
    end

    -- ssh with protocol and explicit port (e.g. ssh://git@host:7999/PROJECT/repo.git)
    -- Verify via REST API since any host:port could look like this; strip port from HTTPS URL
    -- as Bitbucket Server HTTPS typically runs on 443 via a reverse proxy.
    local hostport, pproject, prepo = url:match("^ssh://git@([^/:]+:%d+)/([^/]+)/([^%.]+)%.git$")
    if hostport then
        local hostname = hostport:match("^([^:]+)")
        if is_bitbucket_server(hostname) then
            return "https://" .. hostname .. "/projects/" .. pproject:upper() .. "/repos/" .. prepo .. "/browse"
        end
    end

    -- Portless ssh://git@host/project/repo.git — verify host is Bitbucket Server via REST API
    host, project, repo = url:match("^ssh://git@([^/:]+)/([^~/][^/]*)/([^%.]+)%.git$")
    if host and is_bitbucket_server(host) then
        return "https://" .. host .. "/projects/" .. project:upper() .. "/repos/" .. repo .. "/browse"
    end

    return nil
end

local function transform_url(url, is_bitbucket_server)
    is_bitbucket_server = is_bitbucket_server or function() return false end
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

    -- check bitbucket transformations first
    local bb = transform_bitbucket(url, is_bitbucket_server)
    if bb then
        url = bb
    -- Standard Git fallbacks
    elseif url:match("^git@[^:]+:") then
        url = url:gsub("^git@([^:]+):(.+)$", "https://%1/%2")
    elseif url:match("^ssh://git@") then
        -- Strip SSH port if present — port is SSH-specific, HTTPS runs on 443
        url = url:gsub("^ssh://git@([^/:]+):%d+/(.+)$", "https://%1/%2")
        url = url:gsub("^ssh://git@([^/]+)/(.+)$", "https://%1/%2")
    end

    -- Clean up
    url = url:gsub("%.git$", "")
    url = url:gsub("^https:///", "https://")

    return url
end

return {
    transform_url = transform_url,
    entry = function()
        local function notify(title, content, level)
            ya.notify {
                title = title,
                content = content,
                timeout = 5,
                level = level or "info",
            }
        end

        -- 1. Get remotes using Yazi's async Command API
        local output, err = Command("git"):arg("remote"):output()

        if not output then
            notify("Git Open", "Failed to run git: " .. tostring(err), "error")
            return
        end

        local remotes = {}
        for line in output.stdout:gmatch("[^\r\n]+") do
            table.insert(remotes, line)
        end

        if #remotes == 0 then
            notify("Git Open", "No remotes found", "error")
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
            notify("Git Open", "Failed to get remote url: " .. tostring(err_url), "error")
            return
        end
        local url = output_url.stdout:gsub("[\r\n]+$", "")

        if not url or url == "" then
            notify("Git Open", "Empty remote URL", "error")
            return
        end

        -- 4. Transform URL
        local function is_bitbucket_server(host)
            if known_non_bitbucket[host] then return false end
            load_bb_cache()
            if bitbucket_host_cache[host] ~= nil then
                return bitbucket_host_cache[host]
            end
            local out = Command("curl")
                :arg("-s"):arg("-o"):arg("/dev/null")
                :arg("-w"):arg("%{http_code}")
                :arg("--max-time"):arg("3")
                :arg("https://" .. host .. "/rest/api/1.0/application-properties")
                :output()
            local code = out and out.stdout and out.stdout:gsub("%s+", "") or "000"
            -- 200 = public, 401/403 = auth required but endpoint exists — both confirm Bitbucket Server
            local result = (code == "200" or code == "401" or code == "403")
            bitbucket_host_cache[host] = result
            if result then persist_bb_host(host) end
            return result
        end

        url = transform_url(url, is_bitbucket_server)

        -- 5. Open URL
        if package.config:sub(1, 1) == "\\" then
            -- Windows: use cmd /c start to safely handle URLs with special characters
            Command("cmd"):arg("/c"):arg("start"):arg(""):arg(url):output()
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
                    pcall(notify, "Git Open", "Failed to open URL with command: " .. cmd, "error")
                end
            else
                notify("Git Open", "No browser opener found (install xdg-utils or a browser)", "error")
            end
        end
    end
}
