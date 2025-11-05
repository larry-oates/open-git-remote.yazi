# open-git-remote.yazi
Plugin for [Yazi](https://github.com/sxyazi/yazi) to open git repos's remote url quickly with a shortcut.  
Jump to the github page from yazi!

Inspired by [Sylvan Franklin](https://www.youtube.com/watch?v=YDd0MYtfIp8&t=153s)
## Dependencies
- Git
- A web browser
- A browser opener:
  - `open` (macOS)
  - `xdg-open` (Linux)
  - `start` (Windows/Git Bash)
  - `wslview` (WSL)
  - [GitHub CLI (`gh`)](https://cli.github.com/) - (**and/or** - just opens github links)



## Installation

### Using `ya pkg`
```
 ya pkg add larry-oates/open-git-remote
```

### Manual
**Linux/macOS**
```
git clone https://github.com/larry-oates/open-git-remote.yazi.git ~/.config/yazi/plugins/open-git-remote.yazi
```
**Windows**
```
git clone https://github.com/larry-oates/open-git-remote.yazi.git %AppData%\yazi\config\plugins\open-git-remote.yazi
```
## Configuration
add this to your **keymap.toml** file:
```toml
[[mgr.prepend_keymap]]
on   = [ "g", "l" ]
run  = "plugin open-git-remote"
desc = "open git remote url"
```
I use g then l for "Git Link" but you can customize the keybinding however you like. Please refer to the [keymap.toml](https://yazi-rs.github.io/docs/configuration/keymap) documentation

