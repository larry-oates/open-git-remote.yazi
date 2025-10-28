-- ~/.config/yazi/plugins/git-open.yazi/init.lua
-- Plugin to open Git remote URL in browser

return {
	entry = function()
		ya.manager_emit("shell", {
			[[
				# Get git root
				git_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
					echo "Not in a Git repository" >&2
					exit 1
				}
				
				# Get remote URL
				remote_url=$(cd "$git_root" && git remote get-url origin 2>/dev/null) || {
					echo "No remote 'origin' found" >&2
					exit 1
				}
				
				# Convert SSH URL to HTTPS
				browser_url=$(echo "$remote_url" | sed -E '
					s|^https?://(.+)\.git$|https://\1|;
					s|^git@([^:]+):(.+)\.git$|https://\1/\2|;
					s|^git@([^:]+):(.+)$|https://\1/\2|;
					s|^ssh://git@([^/]+)/(.+)\.git$|https://\1/\2|;
					s|^ssh://git@([^/]+)/(.+)$|https://\1/\2|
				')
				
				# Open in browser (try multiple commands)
				if command -v open >/dev/null 2>&1; then
					open "$browser_url"
				elif command -v xdg-open >/dev/null 2>&1; then
					xdg-open "$browser_url"
				elif command -v start >/dev/null 2>&1; then
					start "$browser_url"
				elif command -v wslview >/dev/null 2>&1; then
					wslview "$browser_url"
				else
					echo "No browser opener found" >&2
					exit 1
				fi
				
				echo "Opened: $browser_url"
			]],
			confirm = false,
			orphan = true,
		})
	end,
}
