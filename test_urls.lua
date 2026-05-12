-- Test suite for open-git-remote.yazi URL transformations
-- Run with: lua test_urls.lua

-- Load the real plugin and use its exported transform_url
local plugin = dofile(debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") .. "main.lua")
local transform_url = plugin.transform_url

-- Mock host checker: returns true for known Bitbucket test hosts.
-- Known public forges are skipped before this is ever called (via known_non_bitbucket table).
local bitbucket_hosts = { ["bitbucket.example.com"] = true }
local function mock_is_bitbucket(host) return bitbucket_hosts[host] == true end

-- ── Test runner ───────────────────────────────────────────────────────────────

local pass, fail = 0, 0

local function test(description, input, expected)
    local got = transform_url(input, mock_is_bitbucket)
    if got == expected then
        print(string.format("  ✓  %s", description))
        pass = pass + 1
    else
        print(string.format("  ✗  %s", description))
        print(string.format("       input:    %s", input))
        print(string.format("       expected: %s", expected))
        print(string.format("       got:      %s", got))
        fail = fail + 1
    end
end

-- ── Test cases ────────────────────────────────────────────────────────────────

print("\n── GitHub ───────────────────────────────────────────────────────────────")
test("SSH (git@)",
    "git@github.com:user/repo.git",
    "https://github.com/user/repo")
test("SSH (git@) without .git",
    "git@github.com:user/repo",
    "https://github.com/user/repo")
test("SSH (ssh:// protocol)",
    "ssh://git@github.com/user/repo.git",
    "https://github.com/user/repo")
test("HTTPS passthrough",
    "https://github.com/user/repo.git",
    "https://github.com/user/repo")
test("HTTPS passthrough without .git",
    "https://github.com/user/repo",
    "https://github.com/user/repo")

print("\n── GitLab ───────────────────────────────────────────────────────────────")
test("SSH (git@)",
    "git@gitlab.com:group/project.git",
    "https://gitlab.com/group/project")
test("SSH (git@) nested subgroup",
    "git@gitlab.com:group/subgroup/project.git",
    "https://gitlab.com/group/subgroup/project")
test("SSH (ssh:// protocol)",
    "ssh://git@gitlab.com/group/project.git",
    "https://gitlab.com/group/project")
test("HTTPS passthrough",
    "https://gitlab.com/group/project.git",
    "https://gitlab.com/group/project")

print("\n── Azure DevOps ─────────────────────────────────────────────────────────")
test("git@ on ssh.dev.azure.com",
    "git@ssh.dev.azure.com:v3/myorg/myproject/myrepo",
    "https://dev.azure.com/myorg/myproject/_git/myrepo")
test("ssh:// on ssh.dev.azure.com (no port)",
    "ssh://git@ssh.dev.azure.com/v3/myorg/myproject/myrepo",
    "https://dev.azure.com/myorg/myproject/_git/myrepo")
test("ssh:// on ssh.dev.azure.com (with port 22)",
    "ssh://git@ssh.dev.azure.com:22/v3/myorg/myproject/myrepo",
    "https://dev.azure.com/myorg/myproject/_git/myrepo")
test("git@ on vs-ssh.visualstudio.com",
    "git@vs-ssh.visualstudio.com:v3/myorg/myproject/myrepo",
    "https://dev.azure.com/myorg/myproject/_git/myrepo")
test("ssh:// on vs-ssh.visualstudio.com (no port)",
    "ssh://git@vs-ssh.visualstudio.com/v3/myorg/myproject/myrepo",
    "https://dev.azure.com/myorg/myproject/_git/myrepo")
test("ssh:// on vs-ssh.visualstudio.com (with port 22)",
    "ssh://git@vs-ssh.visualstudio.com:22/v3/myorg/myproject/myrepo",
    "https://dev.azure.com/myorg/myproject/_git/myrepo")

print("\n── Bitbucket Server / Data Center ───────────────────────────────────────")
test("SSH git@ form – generic SSH (no reliable Bitbucket-only indicator)",
    "git@bitbucket.example.com:PROJ/my-repo.git",
    "https://bitbucket.example.com/PROJ/my-repo")
test("HTTPS /scm/ form",
    "https://bitbucket.example.com/scm/PROJ/my-repo.git",
    "https://bitbucket.example.com/projects/PROJ/repos/my-repo/browse")
test("HTTPS /scm/ form without .git",
    "https://bitbucket.example.com/scm/PROJ/my-repo",
    "https://bitbucket.example.com/projects/PROJ/repos/my-repo/browse")
test("SSH ssh:// form without port – Bitbucket Server (detected via REST API)",
    "ssh://git@bitbucket.example.com/PROJ/my-repo.git",
    "https://bitbucket.example.com/projects/PROJ/repos/my-repo/browse")
test("SSH ssh:// form without port – lowercase project key uppercased",
    "ssh://git@bitbucket.example.com/proj/my-repo.git",
    "https://bitbucket.example.com/projects/PROJ/repos/my-repo/browse")
test("SSH ssh:// form without port – non-Bitbucket host falls through to generic SSH",
    "ssh://git@github.com/user/repo.git",
    "https://github.com/user/repo")
test("SSH ssh:// form with port",
    "ssh://git@bitbucket.example.com:7999/PROJ/my-repo.git",
    "https://bitbucket.example.com/projects/PROJ/repos/my-repo/browse")
test("SSH ssh:// form with port – lowercase project key uppercased",
    "ssh://git@bitbucket.example.com:7999/proj/my-repo.git",
    "https://bitbucket.example.com/projects/PROJ/repos/my-repo/browse")
test("Personal repo ssh:// form (~username)",
    "ssh://git@bitbucket.example.com/~jsmith/my-repo.git",
    "https://bitbucket.example.com/users/jsmith/repos/my-repo/browse")
test("Personal repo git@ form (~username)",
    "git@bitbucket.example.com:~jsmith/my-repo.git",
    "https://bitbucket.example.com/users/jsmith/repos/my-repo/browse")

print("\n── Bitbucket Cloud ──────────────────────────────────────────────────────")
test("SSH (git@)",
    "git@bitbucket.org:user/repo.git",
    "https://bitbucket.org/user/repo")
test("HTTPS passthrough",
    "https://user@bitbucket.org/user/repo.git",
    "https://user@bitbucket.org/user/repo")

print("\n── Gitea / Forgejo / self-hosted generic ────────────────────────────────")
test("SSH (git@)",
    "git@gitea.example.com:user/repo.git",
    "https://gitea.example.com/user/repo")
test("HTTPS passthrough",
    "https://gitea.example.com/user/repo.git",
    "https://gitea.example.com/user/repo")
test("SSH ssh:// with non-standard port – port stripped from HTTPS URL",
    "ssh://git@gitea.example.com:2222/user/repo.git",
    "https://gitea.example.com/user/repo")
test("SSH ssh:// with port 22 – port stripped from HTTPS URL",
    "ssh://git@github.com:22/user/repo.git",
    "https://github.com/user/repo")
test("SSH ssh:// github.com – known forge, no Bitbucket probe",
    "ssh://git@github.com/user/repo.git",
    "https://github.com/user/repo")
test("SSH ssh:// gitlab.com – known forge, no Bitbucket probe",
    "ssh://git@gitlab.com/group/repo.git",
    "https://gitlab.com/group/repo")

-- ── Summary ───────────────────────────────────────────────────────────────────
print(string.format("\n%d passed, %d failed\n", pass, fail))
if fail > 0 then os.exit(1) end
