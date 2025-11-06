-- ~/.config/yazi/plugins/git-open.yazi/init.lua
-- Plugin to open Git remote URL in browser

return {
	entry = function()
		ya.emit("shell", {
			[[
				# Check if we're in a git repository
				if ! git rev-parse --git-dir >/dev/null 2>&1; then
					echo "Not in a Git repository" >&2
					exit 1
				fi
				
				# Try gh browse first (best option for GitHub repos)
				if command -v gh >/dev/null 2>&1; then
					if gh browse 2>/dev/null; then
						echo "Opened with gh browse"
						exit 0
					fi
				fi
				
				# Fallback: Get remote URL and open manually
				remote_url=$(git remote get-url origin 2>/dev/null) || {
					echo "No remote 'origin' found" >&2
					exit 1
				}
				
				# Convert SSH URL to HTTPS
				browser_url=$(echo "$remote_url" | sed -E '
					s|^https?://(.+)\.git$|https://\1|;
					s|^https?://(.+)$|https://\1|;
					s|^git@([^:]+):(.+)\.git$|https://\1/\2|;
					s|^git@([^:]+):(.+)$|https://\1/\2|;
					s|^ssh://git@([^/]+)/(.+)\.git$|https://\1/\2|;
					s|^ssh://git@([^/]+)/(.+)$|https://\1/\2|
				')
				
				# Open in browser
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
